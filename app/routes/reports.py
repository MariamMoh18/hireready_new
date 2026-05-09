from io import BytesIO

from flask import send_file
from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort

from ..models import InterviewSession, db


reports_bp = Blueprint(
    "reports",
    __name__,
    url_prefix="/sessions",
    description="Interview report and export endpoints",
)


def _get_session_for_user(session_id: int) -> InterviewSession:
    user_id = int(get_jwt_identity())
    session = db.session.get(InterviewSession, session_id)
    if not session or session.user_id != user_id:
        abort(404, message="Session not found")
    return session


@reports_bp.route("/<int:session_id>/report")
class SessionReport(MethodView):
    @jwt_required()
    def get(self, session_id):
        session = _get_session_for_user(session_id)

        last_score = None
        if session.answers:
            last_answer = session.answers[-1]
            last_score = last_answer.score

        return {
            "id": session.id,
            "overall_score": session.overall_score,
            "voice_tone_score": last_score.voice_tone_score if last_score else None,
            "facial_expression_score": last_score.facial_expression_score if last_score else None,
            "content_quality_score": last_score.content_quality_score if last_score else None,
            "analysis_results": session.analysis_results,
            "answers": [
                {
                    "question_text": answer.question.question_text if answer.question else "Question not available",
                    "answer_text": answer.answer_text or "",
                    "facial_confidence": answer.facial_confidence,
                    "eye_contact_percentage": answer.eye_contact_percentage,
                    "stress_level": answer.stress_level,
                    "engagement_score": answer.engagement_score,
                    "words_per_minute": answer.words_per_minute,
                    "filler_count": answer.filler_count,
                    "score": {
                        "technical_score": answer.score.technical_score if answer.score else None,
                        "communication_score": answer.score.communication_score if answer.score else None,
                        "confidence_score": answer.score.confidence_score if answer.score else None,
                        "overall_score": answer.score.overall_score if answer.score else None,
                    },
                    "feedback": {
                        "strengths": answer.feedback.strengths if answer.feedback else None,
                        "weaknesses": answer.feedback.weaknesses if answer.feedback else None,
                        "suggestions": answer.feedback.suggestions if answer.feedback else None,
                    },
                }
                for answer in session.answers
            ],
        }


@reports_bp.route("/<int:session_id>/export")
class SessionExport(MethodView):
    @jwt_required()
    def get(self, session_id):
        session = _get_session_for_user(session_id)
        try:
            from reportlab.pdfgen import canvas
            from reportlab.lib.pagesizes import LETTER
        except ModuleNotFoundError:
            abort(501, message="PDF export is unavailable because reportlab is not installed.")

        buffer = BytesIO()
        pdf = canvas.Canvas(buffer, pagesize=LETTER)

        pdf.setFont("Helvetica-Bold", 16)
        pdf.drawString(
            100,
            750,
            f"Interview Report: {session.job_position.title if session.job_position else 'General'}",
        )

        pdf.setFont("Helvetica", 12)
        pdf.drawString(100, 730, f"Date: {session.start_time.strftime('%Y-%m-%d %H:%M')}")
        pdf.drawString(100, 715, f"Overall Confidence Score: {int(session.overall_score or 0)}%")

        y = 680
        for index, answer in enumerate(session.answers, start=1):
            question_text = answer.question.question_text if answer.question else "Question unavailable"
            answer_text = answer.answer_text or "Answer unavailable"
            pdf.setFont("Helvetica-Bold", 10)
            pdf.drawString(100, y, f"Q{index}: {question_text[:80]}...")
            y -= 15
            pdf.setFont("Helvetica", 10)
            pdf.drawString(120, y, f"Ans: {answer_text[:90]}...")
            y -= 30
            if y < 100:
                pdf.showPage()
                y = 750

        pdf.showPage()
        pdf.save()

        buffer.seek(0)
        return send_file(
            buffer,
            as_attachment=True,
            download_name=f"Interview_Report_{session_id}.pdf",
            mimetype="application/pdf",
        )
