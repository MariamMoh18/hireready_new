from datetime import datetime, timedelta

from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort
from sqlalchemy import func

from ..models import InterviewSession, Answer, Score, db


dashboard_bp = Blueprint(
    "dashboard",
    __name__,
    url_prefix="/dashboard",
    description="Dashboard and user analytics endpoints",
)


@dashboard_bp.route("/stats")
class DashboardStats(MethodView):
    @jwt_required()
    def get(self):
        user_id = int(get_jwt_identity())
        one_week_ago = datetime.utcnow() - timedelta(days=7)

        avg_score = db.session.query(func.avg(InterviewSession.overall_score)).filter(
            InterviewSession.user_id == user_id,
            InterviewSession.status == "completed",
            InterviewSession.end_time >= one_week_ago,
        ).scalar() or 0

        total_time = db.session.query(func.sum(InterviewSession.duration)).filter(
            InterviewSession.user_id == user_id,
            InterviewSession.status == "completed",
        ).scalar() or 0
        total_minutes = round(total_time / 60) if isinstance(total_time, (int, float)) else 0

        return {
            "weekly_avg_confidence": round(float(avg_score), 1),
            "total_practice_minutes": total_minutes,
            "status_message": (
                "Your average confidence score this week is higher than last week!"
                if avg_score > 50
                else "Keep practicing to improve your scores."
            ),
        }


@dashboard_bp.route("/progress")
class DashboardProgress(MethodView):
    @jwt_required()
    def get(self):
        user_id = int(get_jwt_identity())

        sessions = (
            InterviewSession.query
            .filter_by(user_id=user_id, status="completed")
            .order_by(InterviewSession.end_time.asc())
            .all()
        )

        print(f"[DEBUG] /dashboard/progress: user={user_id}, found {len(sessions)} completed sessions")
        for s in sessions:
            print(f"[DEBUG]   session id={s.id}, duration_raw={s.duration}s, start={s.start_time}, end={s.end_time}")

        if not sessions:
            return {
                "avg_score": 0,
                "best_score": 0,
                "total_practice_minutes": 0,
                "total_sessions": 0,
                "performance_trend": [],
                "category_averages": {
                    "voice_tone": 0,
                    "facial_expression": 0,
                    "content_quality": 0,
                },
            }

        scores = [s.overall_score or 0 for s in sessions]
        avg_score = round(sum(scores) / len(scores), 1)
        best_score = round(max(scores))
        total_seconds = sum(s.duration or 0 for s in sessions)
        total_minutes = round(total_seconds / 60)
        print(f"[DEBUG] /dashboard/progress: total_seconds={total_seconds}, total_minutes={total_minutes}")

        performance_trend = [
            {
                "date": s.end_time.strftime("%Y-%m-%d") if s.end_time else "unknown",
                "score": round(s.overall_score or 0),
            }
            for s in sessions
        ]

        # Collect category scores from Score model (attached to last answer of each session)
        voice_scores = []
        facial_scores = []
        content_scores = []
        for session in sessions:
            if session.answers:
                last_answer = session.answers[-1]
                if last_answer.score:
                    if last_answer.score.voice_tone_score is not None:
                        voice_scores.append(last_answer.score.voice_tone_score)
                    if last_answer.score.facial_expression_score is not None:
                        facial_scores.append(last_answer.score.facial_expression_score)
                    if last_answer.score.content_quality_score is not None:
                        content_scores.append(last_answer.score.content_quality_score)

        return {
            "avg_score": avg_score,
            "best_score": best_score,
            "total_practice_minutes": total_minutes,
            "total_sessions": len(sessions),
            "performance_trend": performance_trend,
            "category_averages": {
                "voice_tone": round(sum(voice_scores) / len(voice_scores), 1) if voice_scores else 0,
                "facial_expression": round(sum(facial_scores) / len(facial_scores), 1) if facial_scores else 0,
                "content_quality": round(sum(content_scores) / len(content_scores), 1) if content_scores else 0,
            },
        }
