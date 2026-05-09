from datetime import datetime
from pathlib import Path
from tempfile import NamedTemporaryFile

from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort

from ..Mind.graph import build_graph
from ..models import AIModel, Answer, InterviewQuestion, InterviewSession, JobPosition, db
from ..schemas import (
    AnswerDetailSchema,
    AnswerFinalizeResponseSchema,
    AnswerFinalizeSchema,
    AnswerStartResponseSchema,
    AnswerStartSchema,
    AudioAnswerFileSchema,
    AudioAnswerFormSchema,
    BaselineResponseSchema,
    BaselineUploadFileSchema,
    ChunkResponseSchema,
    ChunkUploadFileSchema,
    ChunkUploadFormSchema,
    QuestionDetailSchema,
    SessionAnswersListSchema,
    SessionCancelResponseSchema,
    SessionCompleteResponseSchema,
    SessionCreateSchema,
    SessionFinalizeSchema,
    SessionListSchema,
    SessionQuestionResponseSchema,
    SessionQuestionsListSchema,
    SessionSchema,
    SessionStateSchema,
)
from ..services.audio.audio_chunk_analyzer import AudioChunkAnalyzer
from ..services.feedback_generator import FeedbackGenerator
from ..services.model_registry import get_stt_service
from ..services.realtime.chunk_pipeline import (
    ChunkProcessingOptions,
    RealtimeChunkPipeline,
    cleanup_chunk_file,
)
from ..services.scoring_service import ScoringSystem

sessions_bp = Blueprint("sessions", __name__, url_prefix="/sessions", description="Operations on interview sessions")
interview_graph = build_graph()


def _get_session_for_user(session_id: int) -> InterviewSession:
    user_id = int(get_jwt_identity())
    session = db.session.get(InterviewSession, session_id)
    if not session or session.user_id != user_id:
        abort(404, message="Session not found")
    return session


def _session_analysis(session: InterviewSession) -> dict:
    return session.analysis_results or {}


def _persist_session_analysis(session: InterviewSession, analysis_results: dict) -> None:
    session.analysis_results = analysis_results


def _build_mind_state(session: InterviewSession) -> dict:
    analysis_results = _session_analysis(session)
    stored_state = analysis_results.get("mind_state") or {}

    return {
        "session_id": session.id,
        "messages": stored_state.get("messages", []),
        "question_count": stored_state.get("question_count", 0),
        "max_questions": session.max_questions,
        "current_question": stored_state.get("current_question"),
        "pending_answer": stored_state.get("pending_answer"),
        "is_finished": stored_state.get("is_finished", False),
        "master_baseline": session.master_baseline,
        "current_behavioral_metrics": stored_state.get("current_behavioral_metrics"),
        "current_answer_id": stored_state.get("current_answer_id"),
        "current_partial_transcript": stored_state.get("current_partial_transcript"),
        "answer_processing_status": stored_state.get("answer_processing_status", "idle"),
        "last_chunk_index": stored_state.get("last_chunk_index"),
        "job_title": session.job_position.title if session.job_position else "General Position",
        "job_level": session.job_position.level if session.job_position else "",
        "job_skills": [skill.name for skill in (session.job_position.skills if session.job_position else [])],
    }


def _save_mind_state(session: InterviewSession, state: dict) -> None:
    analysis_results = _session_analysis(session)
    analysis_results["mind_state"] = {
        "messages": state.get("messages", []),
        "question_count": state.get("question_count", 0),
        "current_question": state.get("current_question"),
        "pending_answer": state.get("pending_answer"),
        "is_finished": state.get("is_finished", False),
        "current_behavioral_metrics": state.get("current_behavioral_metrics"),
        "current_answer_id": state.get("current_answer_id"),
        "current_partial_transcript": state.get("current_partial_transcript"),
        "answer_processing_status": state.get("answer_processing_status", "idle"),
        "last_chunk_index": state.get("last_chunk_index"),
    }
    _persist_session_analysis(session, analysis_results)


def _active_question_id(session: InterviewSession) -> int | None:
    return _session_analysis(session).get("active_question_id")


def _set_active_question(session: InterviewSession, question_id: int | None) -> None:
    analysis_results = _session_analysis(session)
    analysis_results["active_question_id"] = question_id
    _persist_session_analysis(session, analysis_results)


def _set_active_answer(session: InterviewSession, answer_id: int | None) -> None:
    analysis_results = _session_analysis(session)
    analysis_results["active_answer_id"] = answer_id
    _persist_session_analysis(session, analysis_results)


def _save_uploaded_file(storage_file, subdir: str, fallback_name: str) -> str:
    upload_dir = Path(Path(__file__).resolve().parents[1] / "uploads" / subdir)
    upload_dir.mkdir(parents=True, exist_ok=True)
    suffix = Path(storage_file.filename or fallback_name).suffix or Path(fallback_name).suffix

    with NamedTemporaryFile(delete=False, suffix=suffix, dir=upload_dir) as temp_file:
        storage_file.save(temp_file)
        return temp_file.name


def _require_session_in_progress(session: InterviewSession) -> None:
    if session.status != "in_progress":
        abort(409, message="Session is not active.")


def _create_session(session_data):
    user_id = get_jwt_identity()

    position_id = session_data.get("position_id")
    job = None
    if position_id is not None:
        job = db.session.get(JobPosition, position_id)
    if job is None:
        job_field = session_data.get("job_field", "")
        job = JobPosition.query.filter(
            JobPosition.title.ilike(f"%{job_field}%")
        ).first()
    if job is None:
        job = JobPosition.query.first()
    if job is None:
        abort(400, message="No job position found. Please set up job positions first.")

    latest_model = AIModel.query.order_by(AIModel.created_at.desc()).first()
    ui_defaults = {"quick": 5, "standard": 10, "full": 15}
    session_type = session_data.get("session_type", "standard")

    session = InterviewSession(
        user_id=user_id,
        job_position_id=job.id,
        ai_model_id=latest_model.id if latest_model else None,
        status="in_progress",
        session_type=session_type,
        max_questions=session_data.get("max_questions", ui_defaults.get(session_type, 10)),
        analysis_results={},
    )
    db.session.add(session)
    db.session.commit()

    _save_mind_state(session, _build_mind_state(session))
    db.session.commit()
    return session


@sessions_bp.route("")
class SessionCreate(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionListSchema)
    def get(self):
        user_id = int(get_jwt_identity())
        sessions = (
            InterviewSession.query
            .filter_by(user_id=user_id)
            .order_by(InterviewSession.start_time.desc())
            .all()
        )
        return {"sessions": sessions}

    @jwt_required()
    @sessions_bp.arguments(SessionCreateSchema)
    @sessions_bp.response(201, SessionSchema)
    def post(self, session_data):
        return _create_session(session_data)


@sessions_bp.route("/start")
class SessionStartCompatibility(MethodView):
    @jwt_required()
    @sessions_bp.arguments(SessionCreateSchema)
    @sessions_bp.response(201, SessionSchema)
    def post(self, session_data):
        return _create_session(session_data)


@sessions_bp.route("/<int:session_id>/questions/next")
class SessionNextQuestion(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionQuestionResponseSchema)
    def post(self, session_id):
        session = _get_session_for_user(session_id)
        _require_session_in_progress(session)

        active_answer_id = _session_analysis(session).get("active_answer_id")
        if active_answer_id:
            abort(409, message="Finish the current answer before requesting the next question.")

        active_question_id = _active_question_id(session)
        if active_question_id:
            existing_question = db.session.get(InterviewQuestion, active_question_id)
            if existing_question:
                return {
                    "session_id": session.id,
                    "question_id": existing_question.id,
                    "question_text": existing_question.question_text,
                    "question_count": _build_mind_state(session).get("question_count", 0),
                    "is_finished": False,
                }

        state = _build_mind_state(session)
        out = interview_graph.invoke(state)
        state.update(out)
        _save_mind_state(session, state)

        if state.get("is_finished"):
            db.session.commit()
            return {
                "session_id": session.id,
                "question_id": None,
                "question_text": "",
                "question_count": state.get("question_count", 0),
                "is_finished": True,
            }

        question_text = state.get("current_question")
        question = InterviewQuestion(question_text=question_text, session_id=session.id)
        db.session.add(question)
        db.session.flush()
        _set_active_question(session, question.id)
        db.session.commit()

        return {
            "session_id": session.id,
            "question_id": question.id,
            "question_text": question.question_text,
            "question_count": state.get("question_count", 0),
            "is_finished": False,
        }


@sessions_bp.route("/<int:session_id>")
class SessionDetail(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionSchema)
    def get(self, session_id):
        session = _get_session_for_user(session_id)
        return session


@sessions_bp.route("/<int:session_id>/state")
class SessionState(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionStateSchema)
    def get(self, session_id):
        session = _get_session_for_user(session_id)

        state = _build_mind_state(session)
        analysis_results = _session_analysis(session)
        return {
            "session_id": session.id,
            "status": session.status,
            "active_question_id": analysis_results.get("active_question_id"),
            "active_answer_id": analysis_results.get("active_answer_id"),
            "current_question": state.get("current_question"),
            "current_answer_id": state.get("current_answer_id"),
            "current_partial_transcript": state.get("current_partial_transcript"),
            "current_behavioral_metrics": state.get("current_behavioral_metrics"),
            "answer_processing_status": state.get("answer_processing_status"),
            "last_chunk_index": state.get("last_chunk_index"),
            "master_baseline": session.master_baseline,
            "is_finished": state.get("is_finished", False),
            "analysis_results": session.analysis_results,
        }


@sessions_bp.route("/<int:session_id>/cancel")
class SessionCancel(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionCancelResponseSchema)
    def post(self, session_id):
        session = _get_session_for_user(session_id)

        session.status = "cancelled"
        session.end_time = datetime.utcnow()

        state = _build_mind_state(session)
        state["is_finished"] = True
        state["answer_processing_status"] = "cancelled"
        _save_mind_state(session, state)

        db.session.commit()
        return {"status": "cancelled", "session_id": session.id}


@sessions_bp.route("/<int:session_id>/answers")
class SessionAnswerStart(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionAnswersListSchema)
    def get(self, session_id):
        session = _get_session_for_user(session_id)
        answers = (
            Answer.query.filter_by(session_id=session_id)
            .order_by(Answer.created_at.asc())
            .all()
        )
        return {"answers": answers}

    @jwt_required()
    @sessions_bp.arguments(AnswerStartSchema)
    @sessions_bp.response(201, AnswerStartResponseSchema)
    def post(self, payload, session_id):
        session = _get_session_for_user(session_id)
        _require_session_in_progress(session)

        active_answer_id = _session_analysis(session).get("active_answer_id")
        if active_answer_id:
            abort(409, message="An answer is already in progress for this session.")

        question_id = payload.get("question_id") or _active_question_id(session)
        if not question_id:
            abort(400, message="A current question is required before starting an answer.")

        question = db.session.get(InterviewQuestion, question_id)
        if not question or question.session_id != session.id:
            abort(404, message="Question not found for this session")

        answer = Answer(session_id=session.id, question_id=question_id)
        db.session.add(answer)
        db.session.flush()

        _set_active_answer(session, answer.id)

        state = _build_mind_state(session)
        state["current_answer_id"] = answer.id
        state["answer_processing_status"] = "recording"
        state["current_partial_transcript"] = None
        state["last_chunk_index"] = None
        _save_mind_state(session, state)

        db.session.commit()
        return {
            "status": "success",
            "session_id": session.id,
            "answer_id": answer.id,
            "question_id": question_id,
        }


@sessions_bp.route("/<int:session_id>/answers/<int:answer_id>")
class SessionAnswerDetail(MethodView):
    @jwt_required()
    @sessions_bp.response(200, AnswerDetailSchema)
    def get(self, session_id, answer_id):
        _get_session_for_user(session_id)
        answer = db.session.get(Answer, answer_id)
        if not answer or answer.session_id != session_id:
            abort(404, message="Answer not found for this session")
        return answer


@sessions_bp.route("/<int:session_id>/answers/<int:answer_id>/chunks")
class SessionAnswerChunkUpload(MethodView):
    @jwt_required()
    @sessions_bp.arguments(ChunkUploadFileSchema, location="files")
    @sessions_bp.arguments(ChunkUploadFormSchema, location="form")
    @sessions_bp.response(201, ChunkResponseSchema)
    def post(self, file_data, form_data, session_id, answer_id):
        session = _get_session_for_user(session_id)
        _require_session_in_progress(session)
        answer = db.session.get(Answer, answer_id)
        if not answer or answer.session_id != session_id:
            abort(404, message="Answer not found for this session")

        temp_path = None
        try:
            temp_path = _save_uploaded_file(file_data["video"], "chunks", "chunk.webm")
            pipeline = RealtimeChunkPipeline()
            result = pipeline.process_video_chunk_file(
                temp_path,
                ChunkProcessingOptions(
                    session_id=session_id,
                    question_id=answer.question_id,
                    answer_id=answer_id,
                    chunk_index=form_data.get("chunk_index", 0),
                    chunk_start_ms=form_data.get("chunk_start_ms"),
                    chunk_end_ms=form_data.get("chunk_end_ms"),
                    is_final=form_data.get("is_final", False),
                    generate_feedback=form_data.get("generate_feedback", False),
                ),
            )

            session = db.session.get(InterviewSession, session_id)
            state = _build_mind_state(session)
            state["current_answer_id"] = answer_id
            state["current_behavioral_metrics"] = result.get("aggregate_metrics")
            state["current_partial_transcript"] = result.get("transcript")
            state["answer_processing_status"] = "processing"
            state["last_chunk_index"] = form_data.get("chunk_index", 0)
            _save_mind_state(session, state)
            db.session.commit()

            return {"status": "success", **result}
        except Exception as e:
            db.session.rollback()
            abort(500, message=f"Chunk processing failed: {str(e)}")
        finally:
            if temp_path:
                cleanup_chunk_file(temp_path)


@sessions_bp.route("/<int:session_id>/chunks")
class SessionChunkUploadCompatibility(MethodView):
    @jwt_required()
    @sessions_bp.arguments(ChunkUploadFileSchema, location="files")
    @sessions_bp.arguments(ChunkUploadFormSchema, location="form")
    @sessions_bp.response(201, ChunkResponseSchema)
    def post(self, file_data, form_data, session_id):
        session = _get_session_for_user(session_id)
        answer_id = _session_analysis(session).get("active_answer_id")
        if not answer_id:
            abort(400, message="No active answer. Create an answer before uploading chunks.")
        return SessionAnswerChunkUpload().post(file_data, form_data, session_id, answer_id)


@sessions_bp.route("/<int:session_id>/baseline")
class SessionBaselineUpload(MethodView):
    @jwt_required()
    @sessions_bp.arguments(BaselineUploadFileSchema, location="files")
    @sessions_bp.response(200, BaselineResponseSchema)
    def post(self, file_data, session_id):
        session = _get_session_for_user(session_id)
        _require_session_in_progress(session)

        temp_path = None
        try:
            temp_path = _save_uploaded_file(file_data["video"], "baseline", "baseline.webm")
            pipeline = RealtimeChunkPipeline()
            baseline = pipeline.build_baseline_from_video(temp_path)
            session.master_baseline = baseline

            state = _build_mind_state(session)
            state["master_baseline"] = baseline
            _save_mind_state(session, state)

            db.session.commit()
            return {
                "status": "success",
                "session_id": session.id,
                "master_baseline": baseline,
            }
        except Exception as e:
            db.session.rollback()
            abort(500, message=f"Baseline processing failed: {str(e)}")
        finally:
            if temp_path:
                cleanup_chunk_file(temp_path)


@sessions_bp.route("/<int:session_id>/questions")
class SessionQuestions(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionQuestionsListSchema)
    def get(self, session_id):
        _get_session_for_user(session_id)
        questions = (
            InterviewQuestion.query
            .filter_by(session_id=session_id)
            .order_by(InterviewQuestion.id.asc())
            .all()
        )
        return {"questions": questions}


@sessions_bp.route("/<int:session_id>/questions/current")
class SessionCurrentQuestion(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionQuestionResponseSchema)
    def get(self, session_id):
        session = _get_session_for_user(session_id)

        question_id = _active_question_id(session)
        question = db.session.get(InterviewQuestion, question_id) if question_id else None
        state = _build_mind_state(session)
        return {
            "session_id": session.id,
            "question_id": question.id if question else None,
            "question_text": question.question_text if question else (state.get("current_question") or ""),
            "question_count": state.get("question_count", 0),
            "is_finished": state.get("is_finished", False),
        }


@sessions_bp.route("/<int:session_id>/questions/<int:question_id>")
class SessionQuestionDetail(MethodView):
    @jwt_required()
    @sessions_bp.response(200, QuestionDetailSchema)
    def get(self, session_id, question_id):
        _get_session_for_user(session_id)
        question = db.session.get(InterviewQuestion, question_id)
        if not question or question.session_id != session_id:
            abort(404, message="Question not found for this session")
        return question


@sessions_bp.route("/<int:session_id>/answers/<int:answer_id>/finalize")
class SessionAnswerFinalize(MethodView):
    @jwt_required()
    @sessions_bp.arguments(AnswerFinalizeSchema)
    @sessions_bp.response(200, AnswerFinalizeResponseSchema)
    def post(self, payload, session_id, answer_id):
        _get_session_for_user(session_id)
        answer = db.session.get(Answer, answer_id)
        if not answer or answer.session_id != session_id:
            abort(404, message="Answer not found for this session")

        try:
            pipeline = RealtimeChunkPipeline()
            result = pipeline.finalize_answer(
                answer_id=answer_id,
                question_text=answer.question.question_text if answer.question else None,
                generate_feedback=payload.get("generate_feedback", True),
            )

            session = db.session.get(InterviewSession, session_id)
            _set_active_answer(session, None)
            state = _build_mind_state(session)
            state["current_answer_id"] = answer_id
            state["current_behavioral_metrics"] = result.get("aggregate_metrics")
            state["current_partial_transcript"] = result.get("answer_text")
            state["answer_processing_status"] = "completed"
            _save_mind_state(session, state)
            db.session.commit()

            return {"status": "success", **result}
        except Exception as e:
            db.session.rollback()
            abort(500, message=f"Answer finalization failed: {str(e)}")


@sessions_bp.route("/<int:session_id>/answers/audio")
class SessionAudioAnswerCompatibility(MethodView):
    @jwt_required()
    @sessions_bp.arguments(AudioAnswerFileSchema, location="files")
    @sessions_bp.arguments(AudioAnswerFormSchema, location="form")
    @sessions_bp.response(201)
    def post(self, file_data, form_data, session_id):
        _get_session_for_user(session_id)
        audio_file = file_data["file"]
        question_text = form_data.get("question_text")

        try:
            # Transcribe
            stt_result = get_stt_service().transcribe(audio_file.read())
            transcript = stt_result.text

            # Compute audio metrics
            audio_analyzer = AudioChunkAnalyzer()
            audio_metrics = audio_analyzer.analyze(stt_result, chunk_duration_ms=None)

            # Always create a new InterviewQuestion with auto-generated ID to avoid PK collisions
            # with the frontend's sequential question numbering
            question = InterviewQuestion(
                question_text=question_text or "Interview question",
                session_id=session_id,
            )
            db.session.add(question)
            db.session.flush()

            # Create Answer linked to the real InterviewQuestion
            answer = Answer(
                session_id=session_id,
                question_id=question.id,
                answer_text=transcript,
                words_per_minute=audio_metrics.get("words_per_minute"),
                filler_count=audio_metrics.get("filler_count"),
            )
            db.session.add(answer)
            db.session.flush()

            FeedbackGenerator.generate_and_save(answer.id, transcript, question.question_text)

            db.session.commit()
            return {
                "status": "success",
                "answer_id": answer.id,
                "transcript": transcript,
            }
        except Exception as e:
            db.session.rollback()
            abort(500, message=f"Submission failed: {str(e)}")


@sessions_bp.route("/<int:session_id>/complete")
class SessionComplete(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionCompleteResponseSchema)
    def post(self, session_id):
        session = _get_session_for_user(session_id)
        _require_session_in_progress(session)

        result = ScoringSystem.process_and_save_final_score(session_id)
        if (session.overall_score is None or session.overall_score == 0) and session.answers:
            avg = sum((answer.facial_confidence or 0) for answer in session.answers) / len(session.answers)
            session.overall_score = round(avg, 2)

        session.status = "completed"
        session.end_time = datetime.utcnow()

        state = _build_mind_state(session)
        state["is_finished"] = True
        _save_mind_state(session, state)

        db.session.commit()
        return {
            "status": "success",
            "session_id": session.id,
            "overall_score": session.overall_score,
            "analysis_results": session.analysis_results,
        }


@sessions_bp.route("/<int:session_id>/finalize")
class SessionFinalizeCompatibility(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionFinalizeSchema)
    def post(self, session_id):
        _get_session_for_user(session_id)
        SessionComplete().post(session_id)
        session = db.session.get(InterviewSession, session_id)
        return session
