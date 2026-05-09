import os
import json
import logging
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI
from app.models import db, Feedback, Answer

load_dotenv()

class FeedbackGenerator:
    @staticmethod
    def generate_and_save(answer_id, transcript, question_text, behavioral_results=None):
        """
        Main entry point: Fetches LLM feedback and saves it directly to the DB.
        """
        # Get LLM feedback
        feedback_data = FeedbackGenerator.generate_behavioral_feedback(
            transcript, 
            question_text, 
            behavioral_results
        )

        # Save to Database
        try:
            existing_feedback = Feedback.query.filter_by(answer_id=answer_id).first()
            
            if existing_feedback:
                existing_feedback.strengths = feedback_data.get("strengths")
                existing_feedback.weaknesses = feedback_data.get("weaknesses")
                existing_feedback.suggestions = feedback_data.get("suggestions")
            else:
                new_feedback = Feedback(
                    answer_id=answer_id,
                    strengths=feedback_data.get("strengths"),
                    weaknesses=feedback_data.get("weaknesses"),
                    suggestions=feedback_data.get("suggestions")
                )
                db.session.add(new_feedback)
            
            db.session.commit()
            logging.info(f"Successfully saved feedback for Answer ID: {answer_id}")
            return True
        except Exception as e:
            logging.error(f"LLM Feedback Error: {e}")

    @staticmethod
    def generate_behavioral_feedback(transcript, question_text, results=None):
        """
        Uses the LLM to turn transcript and CALIBRATED metrics into coaching.
        """
        llm = ChatOpenAI(
            model="gpt-5-mini",       
            temperature=0.4,
            api_key=os.environ.get("OPENAI_API_KEY")
        )
        
        # Prepare metrics string with explicit mention of calibration
        res = results or {}
        metrics_string = f"""
        - Eye Contact: {res.get('eye_contact_score', 'N/A')}%
        - Facial Confidence (Calibrated): {res.get('confidence', 'N/A')}%
        - Engagement Level (Calibrated): {res.get('engagement', 'N/A')}%
        - Stress Level (Calibrated): {res.get('stress', 'N/A')}%
        """

        # Enhanced prompt to utilize the calibration logic
        prompt = f"""
        You are an expert behavioral interview coach. 
        Analyze the following interview response. 
        
        IMPORTANT: The visual metrics provided are CALIBRATED against the user's personal baseline. 
        A 'normal' score represents their natural state; deviations indicate actual behavioral changes.

        Question: {question_text}
        Candidate Answer: "{transcript}"
        
        Visual Metrics:
        {metrics_string}

        Provide feedback in STRICT JSON format:
        {{
            "strengths": "One sentence highlighting a positive aspect of their verbal or non-verbal delivery.",
            "weaknesses": "One sentence identifying an area for improvement based on content or the calibrated metrics.",
            "suggestions": "One specific, actionable tip for the next interview."
        }}
        """

        try:
            raw_response = llm.invoke(prompt).content.strip()
            
            # Clean JSON Markdown
            if "```json" in raw_response:
                raw_response = raw_response.split("```json")[1].split("```")[0].strip()
            elif "```" in raw_response:
                raw_response = raw_response.split("```")[1].split("```")[0].strip()
            
            return json.loads(raw_response)

        except Exception as e:
            logging.error(f"LLM Feedback Error: {e}")
            return {
                "strengths": "Response captured successfully.",
                "weaknesses": "Detailed behavioral analysis is processing.",
                "suggestions": "Maintain consistent eye contact and focus on structured answers."
            }

