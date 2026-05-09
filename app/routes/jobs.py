from datetime import datetime, timedelta
import random
from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort 
from sqlalchemy import func

from ..models import JobPosition, db, Skill
from ..schemas import JobPositionSchema, SkillSchema

# Changed variable name to jobs_bp
jobs_bp = Blueprint("Jobs", __name__, url_prefix="/api/jobs", description="Operations on job positions")    

@jobs_bp.route("/")
class JobPositionsList(MethodView):
    @jobs_bp.response(200, JobPositionSchema(many=True))
    def get(self):
        """Get all available job positions for the user to choose from"""
        return JobPosition.query.all()

@jobs_bp.route("/<int:job_id>")
class JobPositionDetail(MethodView):
    @jobs_bp.response(200, JobPositionSchema)
    def get(self, job_id):
        """Get details of a specific job and its full skill list"""
        job = db.session.get(JobPosition, job_id)
        if not job:
            abort(404, message="Job position not found.")
        return job

@jobs_bp.route("/<int:job_id>/interview-context")
class JobInterviewContext(MethodView):
    @jwt_required()
    def get(self, job_id):
        """
        Returns a formatted string of the job and a subset of skills.
        """
        job = db.session.get(JobPosition, job_id)
        if not job:
            abort(404, message="Job not found")

        all_skills = [f"{s.name} ({s.level})" for s in job.skills]
        
        # Select between 5 to 7 skills for a focused interview
        selected_skills = random.sample(all_skills, min(len(all_skills), 7))

        return {
            "job_title": job.title,
            "description": job.description,
            "focused_skills": selected_skills,
            "prompt_injection": f"The candidate is applying for {job.title}. "
                                f"Focus your questions on: {', '.join(selected_skills)}."
        }