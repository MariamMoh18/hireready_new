from datetime import datetime
from pathlib import Path
from tempfile import NamedTemporaryFile

from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort

from random import sample
from ..Mind.graph import build_graph, generate_batch_questions
from ..utils.job_data import ROLE_QUESTION_POOLS, ROLE_SKILLS, GENERIC_QUESTIONS
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
    SessionDeleteResponseSchema,
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


def _validate_questions_for_role(questions: list[str], job_slug: str) -> list[str]:
    """Filter out questions that mention technologies from unrelated domains."""
    # Define domain keywords that should ONLY appear for their matching roles
    backend_keywords = {"python", "flask", "sqlalchemy", "django", "docker", "redis",
                        "postgresql", "mysql", "api", "restful", "celery", "nginx",
                        "microservice", "backend", "database", "server-side"}
    ai_keywords = {"tensorflow", "pytorch", "opencv", "mediapipe", "neural network",
                   "deep learning", "machine learning", "computer vision", "cnn", "nlp"}
    frontend_keywords = {"react", "redux", "jsx", "css", "html", "dom", "component",
                         "state management", "responsive layout", "webpack", "vite"}
    flutter_keywords = {"flutter", "dart", "widget", "firebase", "stream", "provider",
                        "bloc", "riverpod"}

    # For non-technical roles, ALL tech keywords are cross-domain
    non_technical_slugs = {"graphic_designer", "digital_marketing"}
    all_tech_keywords = backend_keywords | ai_keywords | frontend_keywords | flutter_keywords

    # For technical roles, only block keywords from OTHER tech domains
    role_allowed = {
        "backend_dev": set(),
        "ai_engineer": set(),
        "flutter_dev": set(),
        "frontend_dev": set(),
    }
    role_blocked = {
        "backend_dev": ai_keywords | frontend_keywords | flutter_keywords,
        "ai_engineer": backend_keywords | frontend_keywords | flutter_keywords,
        "flutter_dev": backend_keywords | ai_keywords | frontend_keywords,
        "frontend_dev": backend_keywords | ai_keywords | flutter_keywords,
    }

    if job_slug in non_technical_slugs:
        blocked = all_tech_keywords
    elif job_slug in role_blocked:
        blocked = role_blocked[job_slug]
    else:
        # Unknown role — block all tech by default
        blocked = all_tech_keywords

    validated = []
    for q in questions:
        q_lower = q.lower()
        # Check if question mentions any blocked keyword
        mentions_blocked = any(kw in q_lower for kw in blocked)
        if not mentions_blocked:
            validated.append(q)
        else:
            print(f"[DEBUG] _validate_questions: filtered out cross-domain question: {q[:80]}...")

    return validated


def _generate_session_questions(session: InterviewSession, count: int, job_field_override: str | None = None) -> list[dict]:
    """Generate diverse questions for a session. Tries AI batch generation first, falls back to role-specific pool."""
    # Use the user's requested job_field, not the DB fallback position
    if job_field_override and job_field_override.strip():
        job_title = job_field_override.strip()
        job_level = session.job_position.level if session.job_position else "Junior"
        job_slug = _find_job_slug(job_title)
        # Get skills from ROLE_SKILLS lookup (covers all known roles)
        job_skills = ROLE_SKILLS.get(job_slug, [])
        if not job_skills:
            # Fallback: use DB skills if available
            job_skills = [s.name for s in (session.job_position.skills if session.job_position else [])]
    else:
        job_title = session.job_position.title if session.job_position else ""
        job_level = session.job_position.level if session.job_position else ""
        job_slug = _find_job_slug(job_title)
        job_skills = [s.name for s in (session.job_position.skills if session.job_position else [])]

    # Try AI batch generation
    print(f"[DEBUG] _generate_session_questions: job='{job_title}', level='{job_level}', count={count}")
    ai_questions = generate_batch_questions(job_title, job_level, job_skills, count)
    print(f"[DEBUG] _generate_session_questions: AI returned {len(ai_questions)} questions (need {count})")
    if len(ai_questions) >= count:
        types = ["behavioral", "technical", "technical", "situational", "behavioral",
                 "technical", "behavioral", "technical", "situational", "technical",
                 "behavioral", "technical", "situational", "behavioral", "technical"]
        # Validate: filter out questions with cross-domain keywords
        validated = _validate_questions_for_role(ai_questions[:count], job_slug)
        if len(validated) >= count:
            return [
                {"question_text": q, "type": types[i % len(types)], "difficulty": "intermediate"}
                for i, q in enumerate(validated[:count])
            ]
        print(f"[DEBUG] _generate_session_questions: validation kept only {len(validated)} — falling back to pool")

    # Fallback: role-specific pool
    pool_key = _find_job_slug(job_title)
    pool = ROLE_QUESTION_POOLS.get(pool_key, [])
    if len(pool) < count:
        pool = pool + GENERIC_QUESTIONS

    selected = sample(pool, min(count, len(pool)))
    # Assign types rotation: 0=behavioral, 1-2=technical, 3=situational, 4=behavioral...
    type_pattern = ["behavioral", "technical", "technical", "situational", "behavioral",
                    "technical", "behavioral", "technical", "situational", "technical",
                    "behavioral", "technical", "situational", "behavioral", "technical"]
    return [
        {"question_text": q, "type": type_pattern[i % len(type_pattern)], "difficulty": "intermediate"}
        for i, q in enumerate(selected)
    ]


def _find_job_slug(title: str) -> str:
    """Map a job title to a slug key in ROLE_QUESTION_POOLS."""
    title_lower = title.lower()
    if "backend" in title_lower or "python" in title_lower:
        return "backend_dev"
    if "ai" in title_lower or "computer vision" in title_lower or "machine learning" in title_lower:
        return "ai_engineer"
    if "flutter" in title_lower or "mobile" in title_lower:
        return "flutter_dev"
    if "frontend" in title_lower or "react" in title_lower:
        return "frontend_dev"
    if "graphic" in title_lower or "designer" in title_lower or "visual" in title_lower:
        return "graphic_designer"
    if "digital" in title_lower or "marketing" in title_lower or "seo" in title_lower or "social media" in title_lower:
        return "digital_marketing"
    return ""


def _create_session(session_data):
    user_id = get_jwt_identity()
    print(f"[DEBUG] _create_session: user_id={user_id}, data={session_data}")

    position_id = session_data.get("position_id")
    job = None
    if position_id is not None:
        job = db.session.get(JobPosition, position_id)
        print(f"[DEBUG] _create_session: lookup by position_id={position_id} -> {job.title if job else None}")
    if job is None:
        job_field = session_data.get("job_field", "")
        job = JobPosition.query.filter(
            JobPosition.title.ilike(f"%{job_field}%")
        ).first()
        print(f"[DEBUG] _create_session: lookup by job_field='{job_field}' -> {job.title if job else None}")
    if job is None:
        job = JobPosition.query.first()
        print(f"[DEBUG] _create_session: fallback first job -> {job.title if job else None}")
    if job is None:
        print("[DEBUG] _create_session: NO JOB POSITION FOUND — aborting")
        abort(400, message="No job position found. Please set up job positions first.")

    latest_model = AIModel.query.order_by(AIModel.created_at.desc()).first()
    ui_defaults = {"quick": 5, "standard": 10, "full": 15}
    session_type = session_data.get("session_type", "standard")
    desired_count = session_data.get("max_questions", ui_defaults.get(session_type, 10))
    print(f"[DEBUG] _create_session: session_type={session_type}, desired_count={desired_count}")

    session = InterviewSession(
        user_id=user_id,
        job_position_id=job.id,
        ai_model_id=latest_model.id if latest_model else None,
        status="in_progress",
        session_type=session_type,
        max_questions=desired_count,
        analysis_results={},
    )
    db.session.add(session)
    db.session.commit()

    # Generate diverse questions for this session
    # Pass the original job_field from the request so AI generates role-specific questions
    original_job_field = session_data.get("job_field", "")
    print(f"[DEBUG] _create_session: generating {desired_count} questions for job_field='{original_job_field}'")
    questions = _generate_session_questions(session, desired_count, job_field_override=original_job_field)
    print(f"[DEBUG] _create_session: generated {len(questions)} questions")
    for i, q_data in enumerate(questions):
        print(f"[DEBUG] _create_session: question {i+1}: type={q_data.get('type')}, text={q_data['question_text'][:60]}...")
        q = InterviewQuestion(
            question_text=q_data["question_text"],
            difficulty=q_data.get("difficulty", "intermediate"),
            session_id=session.id,
        )
        db.session.add(q)
    db.session.flush()

    _save_mind_state(session, _build_mind_state(session))
    db.session.commit()

    # Attach generated questions to session for the response
    session._generated_questions = questions
    return session


@sessions_bp.route("")
class SessionCreate(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionListSchema)
    def get(self):
        user_id = int(get_jwt_identity())
        sessions = (
            InterviewSession.query
            .filter_by(user_id=user_id, status="completed")
            .order_by(InterviewSession.start_time.desc())
            .all()
        )
        print(f"[DEBUG] GET /sessions: user={user_id}, found {len(sessions)} completed sessions")
        for s in sessions:
            print(f"[DEBUG]   session id={s.id}, type={s.session_type}, status={s.status}, score={s.overall_score}, duration={s.duration}")
        return {"sessions": sessions}

    def post(self, session_data):
        session = _create_session(session_data)
        questions = getattr(session, '_generated_questions', [])
        questions_data = [
            {"id": i + 1, "question_text": q["question_text"], "type": q.get("type", "technical")}
            for i, q in enumerate(questions)
        ]
        return {
            "success": True,
            "id": session.id,
            "session_id": session.id,
            "data": {
                "session_id": session.id,
                "expires_at": session.end_time.isoformat() if session.end_time else None,
                "questions": questions_data,
            },
        }, 201


@sessions_bp.route("/start")
class SessionStartCompatibility(MethodView):
    @jwt_required()
    @sessions_bp.arguments(SessionCreateSchema)
    def post(self, session_data):
        session = _create_session(session_data)
        questions = getattr(session, '_generated_questions', [])
        questions_data = [
            {"id": i + 1, "question_text": q["question_text"], "type": q.get("type", "technical")}
            for i, q in enumerate(questions)
        ]
        return {
            "success": True,
            "id": session.id,
            "session_id": session.id,
            "data": {
                "session_id": session.id,
                "expires_at": session.end_time.isoformat() if session.end_time else None,
                "questions": questions_data,
            },
        }, 201


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

        if session.start_time and session.end_time:
            delta = session.end_time - session.start_time
            session.duration = int(delta.total_seconds())

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

        # Calculate real duration from start to end
        if session.start_time and session.end_time:
            delta = session.end_time - session.start_time
            session.duration = int(delta.total_seconds())
            print(f"[DEBUG] Session {session_id} duration: start={session.start_time}, end={session.end_time}, delta_sec={session.duration}")
        else:
            print(f"[DEBUG] Session {session_id} duration: missing start_time or end_time, skipping")

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


@sessions_bp.route("/<int:session_id>")
class SessionDelete(MethodView):
    @jwt_required()
    @sessions_bp.response(200, SessionDeleteResponseSchema)
    def delete(self, session_id):
        session = _get_session_for_user(session_id)
        print(f"[DEBUG] DELETE /sessions/{session_id}: user={session.user_id}, status={session.status}, type={session.session_type}")
        db.session.delete(session)
        db.session.commit()
        print(f"[DEBUG] DELETE /sessions/{session_id}: deleted successfully")
        return {"success": True, "message": "Session deleted"}
