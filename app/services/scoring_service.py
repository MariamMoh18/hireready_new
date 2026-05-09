import os
import json
import logging
import re
from langchain_openai import ChatOpenAI

from app.models import InterviewSession, Score, db


class ScoringSystem:
    @staticmethod
    def process_and_save_final_score(session_id):
        """
        Aggregates session data and saves the final AI evaluation.
        """
        try:
            db.session.expire_all()
            session = db.session.get(InterviewSession, session_id)

            if not session or not session.answers:
                logging.warning(f"No answers for session {session_id}. Scoring aborted.")
                return None

            logging.info(f"Processing {len(session.answers)} answers for session {session_id}")

            count = len(session.answers)
            avg_eye = sum((answer.eye_contact_percentage or 0) for answer in session.answers) / count
            avg_conf = sum((answer.facial_confidence or 0) for answer in session.answers) / count
            avg_stress = sum((answer.stress_level or 0) for answer in session.answers) / count
            avg_engagement = sum((answer.engagement_score or 0) for answer in session.answers) / count
            avg_wpm = sum((answer.words_per_minute or 0) for answer in session.answers) / count
            total_filler = sum((answer.filler_count or 0) for answer in session.answers)

            video_metrics = {
                "avg_eye_contact": round(avg_eye, 2),
                "avg_confidence": round(avg_conf, 2),
                "avg_stress": round(avg_stress, 2),
                "avg_engagement": round(avg_engagement, 2),
                "avg_wpm": round(avg_wpm, 2),
                "total_filler": total_filler,
            }

            full_transcript = "\n".join(
                f"Q: {answer.question.question_text if answer.question else 'Question'} | A: {answer.answer_text}"
                for answer in session.answers
            )
            job_description = (
                session.job_position.description
                if session.job_position
                else "General Technical Position"
            )

            scores = ScoringSystem.calculate_final_session_score(
                video_metrics,
                full_transcript,
                job_description,
            )

            if scores is None:
                return None

            final_answer = session.answers[-1]
            score_entry = Score.query.filter_by(answer_id=final_answer.id).first()
            if score_entry is None:
                score_entry = Score(answer_id=final_answer.id)
                db.session.add(score_entry)

            score_entry.technical_score = scores.get("technical_score", 0)
            score_entry.communication_score = scores.get("communication_score", 0)
            score_entry.confidence_score = scores.get("confidence_score", 0)
            score_entry.overall_score = scores.get("overall_score", 0)
            score_entry.voice_tone_score = scores.get("voice_tone_score", 0)
            score_entry.facial_expression_score = scores.get("facial_expression_score", 0)
            score_entry.content_quality_score = scores.get("content_quality_score", 0)

            session.overall_score = scores.get("overall_score", 0)
            session.status = "completed"

            analysis_results = session.analysis_results or {}
            analysis_results.update(
                {
                    "justification": scores.get("justification", "No justification provided."),
                    "behavioral_summary": video_metrics,
                    "practice_verdict": (
                        "Great progress! Keep practicing."
                        if scores.get("overall_score", 0) > 80
                        else "Good effort! Focus on the suggestions to improve."
                    ),
                }
            )
            session.analysis_results = analysis_results

            db.session.commit()
            logging.info(
                f"Final score for session {session_id} saved. "
                f"Confidence: {score_entry.confidence_score}"
            )
            return scores

        except Exception as error:
            db.session.rollback()
            logging.error(f"Scoring system error: {error}")
            return None

    @staticmethod
    def calculate_final_session_score(video_metrics, transcript, job_description):
        llm = ChatOpenAI(
            model="gpt-5-mini",       
            temperature=0.4,
            api_key=os.environ.get("OPENAI_API_KEY")
        )

        prompt = f"""
        You are a supportive interview coach helping a candidate improve their interview skills through practice.
        This is NOT a real hiring evaluation. Your goal is to help the candidate grow.

        ROLE THEY PRACTICED FOR:
        {job_description}

        PRACTICE SESSION TRANSCRIPT:
        {transcript}

        BEHAVIORAL METRICS (from camera analysis):
        - Eye Contact: {video_metrics['avg_eye_contact']}%
        - Facial Confidence: {video_metrics['avg_confidence']}%
        - Stress Level: {video_metrics['avg_stress']}%
        - Engagement: {video_metrics['avg_engagement']}%

        AUDIO METRICS:
        - Avg Speaking Pace: {video_metrics['avg_wpm']} words/min
        - Total Filler Words: {video_metrics['total_filler']}

        Evaluate the practice session and return scores that reflect how ready this candidate is,
        with room to grow. Be constructive and encouraging, not harsh.

        Return STRICT JSON only:
        {{
            "technical_score": <0-100>,
            "communication_score": <0-100>,
            "confidence_score": <0-100>,
            "overall_score": <0-100>,
            "voice_tone_score": <0-100, based on vocal clarity, pace, and filler word usage>,
            "facial_expression_score": <0-100, based on facial confidence, engagement, and eye contact>,
            "content_quality_score": <0-100, based on answer relevance, structure, and depth>,
            "justification": "<constructive coaching feedback, 2-3 sentences, encouraging tone>"
        }}
        """

        try:
            response_obj = llm.invoke(prompt)
            content = response_obj.content.strip()
            match = re.search(r"\{.*\}", content, re.DOTALL)
            if not match:
                raise ValueError("No JSON object found in response")
            return json.loads(match.group(0))

        except Exception as error:
            logging.error(f"Scoring LLM parsing error: {error}")
            # Fallback: compute scores from available behavioral metrics
            conf = video_metrics.get("avg_confidence", 0)
            eye = video_metrics.get("avg_eye_contact", 0)
            engagement = video_metrics.get("avg_engagement", 0)
            stress = video_metrics.get("avg_stress", 0)
            wpm = video_metrics.get("avg_wpm", 0)
            filler = video_metrics.get("total_filler", 0)
            wpm_score = max(0, 100 - abs(140 - wpm) * 1.5) if wpm > 0 else 0
            filler_penalty = min(30, filler * 5)
            voice_tone = round(max(0, min(100, (wpm_score + max(0, 100 - stress)) / 2 - filler_penalty)))
            # When no video data (audio-only mode), use speech metrics as proxy
            has_video = conf > 0 or eye > 0 or engagement > 0
            if not has_video:
                proxy = round(max(55, min(85, wpm_score)))
                filler_adj = round(max(50, 100 - filler_penalty))
                facial_expr = round((proxy + filler_adj) / 2)
                content_qual = round((proxy + filler_adj) / 2)
                conf = proxy
            else:
                facial_expr = round((conf + eye + engagement) / 3)
                content_qual = round((conf + engagement) / 2)
            fallback_overall = round((voice_tone + facial_expr + content_qual) / 3)
            return {
                "technical_score": content_qual,
                "communication_score": round((voice_tone + content_qual) / 2),
                "confidence_score": round(conf),
                "overall_score": fallback_overall,
                "voice_tone_score": voice_tone,
                "facial_expression_score": facial_expr,
                "content_quality_score": content_qual,
                "justification": "Based on observed behavioral metrics during the practice session.",
            }
