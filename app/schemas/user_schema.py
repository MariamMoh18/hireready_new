from marshmallow import fields, validate, Schema, pre_load
from . import ma 
from ..models import (
    db, User, InterviewSession, Answer, JobPosition, 
    Score, Feedback, InterviewQuestion, Skill, AIModel, PromptTemplate
)

# ==========================================
# AUTHENTICATION SCHEMAS
# ==========================================

class UserRegisterSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = User
        load_instance = False
        sqla_session = db.session
        exclude = ("password_hash", "is_admin") # Security: never register as admin
        
    name = fields.Str(required=True)
    email = fields.Email(required=True)
    password = fields.Str(required=True, load_only=True)

class UserLoginSchema(Schema):
    email = fields.Email(required=True)
    password = fields.Str(required=True, load_only=True)

# ==========================================
# CORE DATABASE SCHEMAS
# ==========================================

class UserSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = User
        load_instance = True
        sqla_session = db.session
        exclude = ("password_hash",)
        include_fk = True
        
    id = fields.Int(dump_only=True)
    name = fields.Str(dump_only=True) 
    email = fields.Email(dump_only=True)
    experience_level = fields.Str(validate=validate.OneOf(["Junior", "Mid", "Senior"]))
    created_at = fields.DateTime(dump_only=True)

class SkillSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = Skill
        load_instance = True
        sqla_session = db.session
        include_fk = True

class JobPositionSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = JobPosition
        load_instance = True
        sqla_session = db.session
    
    # Nests the skills inside the job JSON for the Flutter list
    skills = fields.Nested(SkillSchema, many=True, dump_only=True)

class QuestionSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = InterviewQuestion
        load_instance = True
        sqla_session = db.session

class AnswerSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = Answer
        load_instance = True
        sqla_session = db.session
        include_fk = True
        
    facial_confidence = fields.Float(dump_only=True)
    eye_contact_percentage = fields.Float(dump_only=True)
    engagement_score = fields.Float(dump_only=True)

class ScoreSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = Score
        load_instance = True
        sqla_session = db.session
        include_fk = True

class FeedbackSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = Feedback
        load_instance = True
        sqla_session = db.session
        include_fk = True

class SessionSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = InterviewSession
        load_instance = True
        sqla_session = db.session
        include_fk = True
    
    score = fields.Nested("ScoreSchema", dump_only=True)
    feedback = fields.Nested("FeedbackSchema", dump_only=True)
    status = fields.Str(validate=validate.OneOf(["in_progress", "completed", "cancelled"]))
    session_type = fields.Str(dump_only=True)
    max_questions = fields.Int(dump_only=True)
    master_baseline = fields.Dict(dump_only=True)


class SessionQuestionResponseSchema(Schema):
    session_id = fields.Int()
    question_id = fields.Int(allow_none=True)
    question_text = fields.Str()
    question_count = fields.Int()
    is_finished = fields.Bool()


class SessionStateSchema(Schema):
    session_id = fields.Int()
    status = fields.Str()
    active_question_id = fields.Int(allow_none=True)
    active_answer_id = fields.Int(allow_none=True)
    current_question = fields.Str(allow_none=True)
    current_answer_id = fields.Int(allow_none=True)
    current_partial_transcript = fields.Str(allow_none=True)
    current_behavioral_metrics = fields.Dict(allow_none=True)
    answer_processing_status = fields.Str(allow_none=True)
    last_chunk_index = fields.Int(allow_none=True)
    master_baseline = fields.Dict(allow_none=True)
    is_finished = fields.Bool()
    analysis_results = fields.Dict(allow_none=True)


class SessionCancelResponseSchema(Schema):
    status = fields.Str()
    session_id = fields.Int()


class SessionListSchema(Schema):
    sessions = fields.List(fields.Nested(lambda: SessionSchema()))


class AnswerDetailSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = Answer
        load_instance = True
        sqla_session = db.session
        include_fk = True

    feedback = fields.Nested(lambda: FeedbackSchema(), dump_only=True)
    score = fields.Nested(lambda: ScoreSchema(), dump_only=True)
    question_text = fields.Str(attribute="question.question_text", dump_only=True)


class QuestionDetailSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = InterviewQuestion
        load_instance = True
        sqla_session = db.session
        include_fk = True


class SessionAnswersListSchema(Schema):
    answers = fields.List(fields.Nested(AnswerDetailSchema))


class SessionQuestionsListSchema(Schema):
    questions = fields.List(fields.Nested(QuestionDetailSchema))


class AnswerStartSchema(Schema):
    question_id = fields.Int(load_default=None)


class AnswerStartResponseSchema(Schema):
    status = fields.Str()
    session_id = fields.Int()
    answer_id = fields.Int()
    question_id = fields.Int(allow_none=True)


class SessionCompleteResponseSchema(Schema):
    status = fields.Str()
    session_id = fields.Int()
    overall_score = fields.Float(allow_none=True)
    analysis_results = fields.Dict(allow_none=True)

# ==========================================
# AI CONFIGURATION SCHEMAS
# ==========================================

class AIModelSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = AIModel
        load_instance = True
        sqla_session = db.session

class PromptTemplateSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = PromptTemplate
        load_instance = True
        sqla_session = db.session

# ==========================================
# INPUT & ANALYSIS SCHEMAS (Plain Schemas)
# ==========================================

class UserUpdateSchema(Schema):
    name = fields.String()
    experience_level = fields.String(validate=validate.OneOf(["Junior", "Mid", "Senior"]))

class SessionCreateSchema(Schema):
    position_id = fields.Int(required=False, allow_none=True)
    job_field = fields.Str(required=False)
    session_type = fields.Str(
        required=False,
        validate=validate.OneOf(["quick", "standard", "full", "video", "audio"])
    )
    mode = fields.Str(required=False)
    length_type = fields.Str(required=False)
    experience_level = fields.Str(required=False)
    max_questions = fields.Int()

    @pre_load
    def normalize_fields(self, data, **kwargs):
        if "position_id" not in data:
            if "job_position_id" in data:
                data["position_id"] = data.pop("job_position_id")
            elif "job_id" in data:
                data["position_id"] = data.pop("job_id")
            elif "positionId" in data:
                data["position_id"] = data.pop("positionId")

        if "sessionType" in data:
            data["session_type"] = data.pop("sessionType").lower()

        # Map mode → session_type if session_type is video/audio
        st = data.get("session_type")
        if st in ("video", "audio"):
            data["mode"] = data.pop("session_type")
            if "length_type" in data:
                data["session_type"] = data.pop("length_type")
            else:
                data["session_type"] = "standard"
        elif st is None:
            if "mode" in data:
                lt = data.pop("length_type", None)
                data["session_type"] = lt or "standard"

        return data

class AudioAnswerFileSchema(Schema):
    file = fields.Raw(metadata={"type": "string", "format": "binary"}, required=True)


class AudioAnswerFormSchema(Schema):
    question_id = fields.Int(required=True)
    question_text = fields.Str(load_default=None)

class VideoAnalysisSchema(Schema):
    video = fields.Raw(metadata={"type": "string", "format": "binary"}, required=True, load_only=True)
    session_id = fields.Int(required=True)
    question_id = fields.Int(required=True)

class VideoMetricsSchema(Schema):
    confidence = fields.Float()
    eye_contact_score = fields.Float()
    stress = fields.Float()
    engagement = fields.Float()

class VideoFeedbackResponseSchema(Schema):
    strengths = fields.Str()
    suggestions = fields.Str()

class VideoResponseSchema(Schema):
    status = fields.Str()
    answer_id = fields.Int()
    metrics = fields.Nested(VideoMetricsSchema)
    feedback = fields.Nested(VideoFeedbackResponseSchema)


class ChunkUploadFormSchema(Schema):
    chunk_index = fields.Int(load_default=0)
    chunk_start_ms = fields.Int(load_default=None)
    chunk_end_ms = fields.Int(load_default=None)
    is_final = fields.Bool(load_default=False)
    generate_feedback = fields.Bool(load_default=False)


class ChunkUploadFileSchema(Schema):
    video = fields.Raw(metadata={"type": "string", "format": "binary"}, required=True)


class ChunkResponseSchema(Schema):
    status = fields.Str()
    answer_id = fields.Int()
    chunk_id = fields.Int()
    transcript = fields.Str()
    chunk_metrics = fields.Dict()
    audio_metrics = fields.Dict()
    aggregate_metrics = fields.Dict()
    feedback = fields.Dict(allow_none=True)
    langgraph_signal = fields.Dict()


class BaselineUploadFileSchema(Schema):
    video = fields.Raw(metadata={"type": "string", "format": "binary"}, required=True)


class BaselineResponseSchema(Schema):
    status = fields.Str()
    session_id = fields.Int()
    master_baseline = fields.Dict()


class AnswerFinalizeSchema(Schema):
    generate_feedback = fields.Bool(load_default=True)


class AnswerFinalizeResponseSchema(Schema):
    status = fields.Str()
    answer_id = fields.Int()
    aggregate_metrics = fields.Dict()
    answer_text = fields.Str()
    feedback = fields.Dict(allow_none=True)

# ==========================================
# REPORT SCHEMAS
# ==========================================

class AnswerScoreSchema(Schema):
    technical_score = fields.Float(allow_none=True)
    communication_score = fields.Float(allow_none=True)
    confidence_score = fields.Float(allow_none=True)
    overall_score = fields.Float(allow_none=True)

class ReportItemSchema(Schema):
    question_text = fields.Str(attribute="question.question_text")
    answer_text = fields.Str()
    facial_confidence = fields.Float()
    eye_contact_percentage = fields.Float()
    stress_level = fields.Float(allow_none=True)
    engagement_score = fields.Float(allow_none=True)
    words_per_minute = fields.Float(allow_none=True)
    filler_count = fields.Int(allow_none=True)
    score = fields.Nested(AnswerScoreSchema, dump_only=True)
    feedback = fields.Nested(FeedbackSchema)

class SessionReportSchema(Schema):
    id = fields.Int(dump_only=True)
    overall_score = fields.Float()
    voice_tone_score = fields.Float(allow_none=True)
    facial_expression_score = fields.Float(allow_none=True)
    content_quality_score = fields.Float(allow_none=True)
    analysis_results = fields.Dict()
    answers = fields.List(fields.Nested(ReportItemSchema))

class SessionDeleteResponseSchema(Schema):
    success = fields.Bool()
    message = fields.Str()

class SessionFinalizeSchema(ma.SQLAlchemyAutoSchema):
    class Meta:
        model = InterviewSession
        load_instance = True
        sqla_session = db.session
        fields = ("id", "overall_score", "analysis_results", "status", "end_time")
