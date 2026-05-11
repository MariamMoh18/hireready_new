from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
from sqlalchemy import JSON
db = SQLAlchemy()

# USER & AUTHENTICATION

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(180), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    experience_level = db.Column(db.String(50))
    job_field = db.Column(db.String(120))
    target_role = db.Column(db.String(120))
    is_admin = db.Column(db.Boolean, default=False)  # Admin flag for committee demo
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    sessions = db.relationship(
        "InterviewSession",
        backref="user",
        lazy=True,
        cascade="all, delete-orphan"
    )

    def set_password(self, password: str):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password: str) -> bool:
        return check_password_hash(self.password_hash, password)


class TokenBlocklist(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    jti = db.Column(db.String(36), nullable=False, index=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# INTERVIEW STRUCTURE (JOBS & SKILLS)

class JobPosition(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(120), nullable=False)
    description = db.Column(db.Text)
    level = db.Column(db.String(50))

    skills = db.relationship(
        "Skill",
        backref="job_position",
        lazy=True,
        cascade="all, delete-orphan"
    )

    sessions = db.relationship(
        "InterviewSession",
        backref="job_position",
        lazy=True
    )


class Skill(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    level = db.Column(db.String(50))

    job_position_id = db.Column(
        db.Integer,
        db.ForeignKey("job_position.id"),
        nullable=False
    )


# SESSION & AI INTERACTION


class InterviewSession(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    job_position_id = db.Column(db.Integer, db.ForeignKey("job_position.id"), nullable=False)
    ai_model_id = db.Column(db.Integer, db.ForeignKey("ai_model.id"))
    start_time = db.Column(db.DateTime, default=datetime.utcnow)
    end_time = db.Column(db.DateTime)
    duration = db.Column(db.Integer)
    status = db.Column(db.String(20), default="in_progress")
    analysis_results = db.Column(db.JSON)
    overall_score = db.Column(db.Float)
    master_baseline = db.Column(JSON, nullable=True)
    session_type = db.Column(db.String(20), default="standard")
    max_questions = db.Column(db.Integer, default=5)
    questions = db.relationship(
        "InterviewQuestion",
        backref="session",
        lazy=True,
        cascade="all, delete-orphan"
    )

    answers = db.relationship(
        "Answer",
        backref="session",
        lazy=True,
        cascade="all, delete-orphan"
    )

    behavioral_chunks = db.relationship(
        "BehavioralMetricChunk",
        backref="session",
        lazy=True,
        cascade="all, delete-orphan"
    )


class InterviewQuestion(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    question_text = db.Column(db.Text, nullable=False)
    difficulty = db.Column(db.String(20))

    session_id = db.Column(
        db.Integer,
        db.ForeignKey("interview_session.id"),
        nullable=True
    )

    answers = db.relationship(
        "Answer",
        backref="question",
        lazy=True,
        cascade="all, delete-orphan"
    )


class Answer(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.Integer, db.ForeignKey("interview_session.id"), nullable=False)
    question_id = db.Column(db.Integer, db.ForeignKey("interview_question.id"))
    word_timestamps = db.Column(JSON)
    answer_text = db.Column(db.Text)
    duration = db.Column(db.Integer)
    confidence_score = db.Column(db.Float)
    facial_confidence = db.Column(db.Float)
    eye_contact_percentage = db.Column(db.Float)
    stress_level = db.Column(db.Float)
    engagement_score = db.Column(db.Float)
    words_per_minute = db.Column(db.Float)
    filler_count = db.Column(db.Integer)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    feedback = db.relationship(
        "Feedback",
        backref="answer",
        uselist=False,
        cascade="all, delete-orphan"
    )

    score = db.relationship(
        "Score",
        backref="answer",
        uselist=False,
        cascade="all, delete-orphan"
    )

    behavioral_chunks = db.relationship(
        "BehavioralMetricChunk",
        backref="answer",
        lazy=True,
        cascade="all, delete-orphan"
    )


class BehavioralMetricChunk(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.Integer, db.ForeignKey("interview_session.id"), nullable=False, index=True)
    answer_id = db.Column(db.Integer, db.ForeignKey("answer.id"), nullable=False, index=True)
    question_id = db.Column(db.Integer, db.ForeignKey("interview_question.id"), nullable=True, index=True)
    chunk_index = db.Column(db.Integer, nullable=False, default=0)
    chunk_path = db.Column(db.String(500))
    chunk_start_ms = db.Column(db.Integer)
    chunk_end_ms = db.Column(db.Integer)
    transcript_text = db.Column(db.Text)
    transcript_language = db.Column(db.String(32))
    audio_metrics = db.Column(JSON)
    video_metrics = db.Column(JSON)
    confidence_score = db.Column(db.Float)
    stress_level = db.Column(db.Float)
    eye_contact_score = db.Column(db.Float)
    engagement_score = db.Column(db.Float)
    is_final_chunk = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    question = db.relationship(
        "InterviewQuestion",
        backref=db.backref("behavioral_chunks", lazy=True)
    )


# FEEDBACK & SCORING

class Feedback(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    answer_id = db.Column(db.Integer, db.ForeignKey("answer.id"), nullable=False)
    strengths = db.Column(db.Text)
    weaknesses = db.Column(db.Text)
    suggestions = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow) # Added for tracking


class Score(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    answer_id = db.Column(db.Integer, db.ForeignKey("answer.id"), nullable=False)
    technical_score = db.Column(db.Float)
    communication_score = db.Column(db.Float)
    confidence_score = db.Column(db.Float)
    overall_score = db.Column(db.Float)
    voice_tone_score = db.Column(db.Float)
    facial_expression_score = db.Column(db.Float)
    content_quality_score = db.Column(db.Float)


# AI MODEL CONFIGURATION

class AIModel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    model_name = db.Column(db.String(100), nullable=False)
    version = db.Column(db.String(50), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    sessions = db.relationship("InterviewSession", backref="ai_model", lazy=True)
    prompt_templates = db.relationship("PromptTemplate", backref="ai_model", lazy=True)


class PromptTemplate(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)  
    template_text = db.Column(db.Text, nullable=False)
    version = db.Column(db.String(20), default="1.0")              
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    ai_model_id = db.Column(db.Integer, db.ForeignKey("ai_model.id"), nullable=False)
