from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any

from app.models import Answer, BehavioralMetricChunk, InterviewQuestion, InterviewSession, db
from app.services.audio.audio_chunk_analyzer import AudioChunkAnalyzer
from app.services.feedback_generator import FeedbackGenerator
from app.services.model_registry import get_stt_service, get_video_processor


@dataclass
class ChunkProcessingOptions:
    session_id: int
    question_id: int | None = None
    answer_id: int | None = None
    chunk_index: int = 0
    chunk_start_ms: int | None = None
    chunk_end_ms: int | None = None
    is_final: bool = False
    generate_feedback: bool = False
    transcription_source: Any | None = None


class RealtimeChunkPipeline:
    """Analyzes interview chunks incrementally while preserving answer-level scoring."""

    def __init__(self):
        self.video_processor = get_video_processor()
        self.stt_service = get_stt_service()
        self.audio_analyzer = AudioChunkAnalyzer()

    def build_baseline_from_video(self, video_path: str, target_sample_fps: int = 2, max_frames: int = 12) -> dict[str, float]:
        sampled_frames, error = self.video_processor._sample_video_frames(
            video_path,
            target_sample_fps=target_sample_fps,
            max_frames=max_frames,
        )
        if error:
            raise ValueError(error["error"])

        baseline_data = []
        for frame in sampled_frames or []:
            faces = self.video_processor.face_detector.detect(frame)
            for face_data in faces:
                baseline_data.append(
                    self.video_processor.emotion_recognizer.predict(face_data["crop"])
                )

        return self.video_processor.get_baseline_from_data(baseline_data)

    def process_video_chunk_file(self, chunk_path: str, options: ChunkProcessingOptions) -> dict[str, Any]:
        session = db.session.get(InterviewSession, options.session_id)
        if not session:
            raise ValueError("Interview session not found")

        baseline = session.master_baseline or {
            emotion: 0.0 for emotion in self.video_processor.labels.values()
        }

        transcription_source = options.transcription_source or chunk_path
        stt_result = self.stt_service.transcribe(transcription_source)
        audio_metrics = self.audio_analyzer.analyze(
            stt_result=stt_result,
            chunk_duration_ms=self._duration_ms(options),
        )
        video_metrics = self.video_processor.process_video_chunk(
            chunk_path,
            master_baseline=baseline,
        )
        if video_metrics.get("error"):
            video_metrics = {
                "confidence": 50,
                "stress": 20,
                "eye_contact_score": 50,
                "engagement": 50,
                "error": video_metrics["error"],
            }

        answer = self._get_or_create_answer(
            session_id=options.session_id,
            question_id=options.question_id,
            answer_id=options.answer_id,
        )

        chunk_row = BehavioralMetricChunk(
            session_id=options.session_id,
            answer_id=answer.id,
            question_id=options.question_id,
            chunk_index=options.chunk_index,
            chunk_path=os.path.basename(chunk_path),
            chunk_start_ms=options.chunk_start_ms,
            chunk_end_ms=options.chunk_end_ms,
            transcript_text=audio_metrics["transcript"],
            transcript_language=audio_metrics["language"],
            audio_metrics=audio_metrics,
            video_metrics=video_metrics,
            confidence_score=video_metrics.get("confidence"),
            stress_level=video_metrics.get("stress"),
            eye_contact_score=video_metrics.get("eye_contact_score"),
            engagement_score=video_metrics.get("engagement"),
            is_final_chunk=options.is_final,
        )
        db.session.add(chunk_row)
        db.session.flush()

        aggregate_metrics = self._refresh_answer_aggregate(answer)
        self._update_session_realtime_summary(session, answer, chunk_row, aggregate_metrics)

        feedback_payload = None
        if options.generate_feedback or options.is_final:
            FeedbackGenerator.generate_and_save(
                answer_id=answer.id,
                transcript=answer.answer_text or "",
                question_text=self._question_text(options.question_id),
                behavioral_results=aggregate_metrics,
            )
            db.session.refresh(answer)
            if answer.feedback:
                feedback_payload = {
                    "strengths": answer.feedback.strengths,
                    "weaknesses": answer.feedback.weaknesses,
                    "suggestions": answer.feedback.suggestions,
                }

        db.session.commit()

        return {
            "answer_id": answer.id,
            "chunk_id": chunk_row.id,
            "transcript": chunk_row.transcript_text,
            "chunk_metrics": video_metrics,
            "audio_metrics": audio_metrics,
            "aggregate_metrics": aggregate_metrics,
            "feedback": feedback_payload,
            "langgraph_signal": {
                "session_id": session.id,
                "latest_answer_id": answer.id,
                "current_behavioral_metrics": aggregate_metrics,
                "last_chunk_transcript": chunk_row.transcript_text,
            },
        }

    def finalize_answer(
        self,
        answer_id: int,
        question_text: str | None = None,
        generate_feedback: bool = True,
    ) -> dict[str, Any]:
        answer = db.session.get(Answer, answer_id)
        if not answer:
            raise ValueError("Answer not found")

        aggregate_metrics = self._refresh_answer_aggregate(answer)
        feedback_payload = None

        if generate_feedback:
            resolved_question_text = question_text or self._question_text(answer.question_id)
            FeedbackGenerator.generate_and_save(
                answer_id=answer.id,
                transcript=answer.answer_text or "",
                question_text=resolved_question_text,
                behavioral_results=aggregate_metrics,
            )
            db.session.refresh(answer)
            if answer.feedback:
                feedback_payload = {
                    "strengths": answer.feedback.strengths,
                    "weaknesses": answer.feedback.weaknesses,
                    "suggestions": answer.feedback.suggestions,
                }

        db.session.commit()

        return {
            "answer_id": answer.id,
            "aggregate_metrics": aggregate_metrics,
            "answer_text": answer.answer_text or "",
            "feedback": feedback_payload,
        }

    def _get_or_create_answer(
        self,
        session_id: int,
        question_id: int | None,
        answer_id: int | None,
    ) -> Answer:
        answer = db.session.get(Answer, answer_id) if answer_id else None

        if answer is None and question_id is not None:
            answer = Answer.query.filter_by(
                session_id=session_id,
                question_id=question_id,
            ).first()

        if answer is None:
            answer = Answer(session_id=session_id, question_id=question_id)
            db.session.add(answer)
            db.session.flush()

        return answer

    def _refresh_answer_aggregate(self, answer: Answer) -> dict[str, Any]:
        chunks = (
            BehavioralMetricChunk.query.filter_by(answer_id=answer.id)
            .order_by(BehavioralMetricChunk.chunk_index.asc(), BehavioralMetricChunk.created_at.asc())
            .all()
        )

        answer.answer_text = " ".join(
            chunk.transcript_text.strip()
            for chunk in chunks
            if chunk.transcript_text and chunk.transcript_text.strip()
        ).strip()
        answer.word_timestamps = [
            {
                "chunk_id": chunk.id,
                "chunk_index": chunk.chunk_index,
                "segments": (chunk.audio_metrics or {}).get("segments", []),
            }
            for chunk in chunks
        ]
        answer.duration = self._sum_json_metric(chunks, "duration_ms") // 1000
        answer.facial_confidence = self._average_attr(chunks, "confidence_score")
        answer.eye_contact_percentage = self._average_attr(chunks, "eye_contact_score")
        answer.stress_level = self._average_attr(chunks, "stress_level")
        answer.engagement_score = self._average_attr(chunks, "engagement_score")
        answer.words_per_minute = round(self._average_json_metric(chunks, "words_per_minute"), 2)
        answer.filler_count = self._sum_json_metric(chunks, "filler_count")
        answer.confidence_score = round(
            (
                (answer.facial_confidence or 0)
                + (answer.engagement_score or 0)
                + (100 - (answer.stress_level or 0))
            ) / 3,
            2,
        )

        return {
            "confidence": answer.facial_confidence or 0.0,
            "stress": answer.stress_level or 0.0,
            "eye_contact_score": answer.eye_contact_percentage or 0.0,
            "engagement": answer.engagement_score or 0.0,
            "words_per_minute": round(self._average_json_metric(chunks, "words_per_minute"), 2),
            "filler_count": self._sum_json_metric(chunks, "filler_count"),
        }

    def _update_session_realtime_summary(
        self,
        session: InterviewSession,
        answer: Answer,
        chunk: BehavioralMetricChunk,
        aggregate_metrics: dict[str, Any],
    ) -> None:
        analysis_results = session.analysis_results or {}
        analysis_results["realtime"] = {
            "last_answer_id": answer.id,
            "last_chunk_id": chunk.id,
            "last_chunk_index": chunk.chunk_index,
            "latest_transcript": chunk.transcript_text,
            "aggregate_metrics": aggregate_metrics,
        }
        session.analysis_results = analysis_results

    def _question_text(self, question_id: int | None) -> str:
        if not question_id:
            return "Professional interview question"

        question = db.session.get(InterviewQuestion, question_id)
        return question.question_text if question else "Professional interview question"

    def _duration_ms(self, options: ChunkProcessingOptions) -> int | None:
        if options.chunk_start_ms is None or options.chunk_end_ms is None:
            return None
        return max(0, options.chunk_end_ms - options.chunk_start_ms)

    def _average_attr(self, chunks: list[BehavioralMetricChunk], field_name: str) -> float:
        values = [
            getattr(chunk, field_name)
            for chunk in chunks
            if getattr(chunk, field_name) is not None
        ]
        if not values:
            return 0.0
        return round(sum(values) / len(values), 2)

    def _average_json_metric(self, chunks: list[BehavioralMetricChunk], key: str) -> float:
        values = []
        for chunk in chunks:
            payload = chunk.audio_metrics or {}
            if payload.get(key) is not None:
                values.append(payload[key])

        if not values:
            return 0.0
        return sum(values) / len(values)

    def _sum_json_metric(self, chunks: list[BehavioralMetricChunk], key: str) -> int:
        total = 0
        for chunk in chunks:
            payload = chunk.audio_metrics or {}
            value = payload.get(key)
            if isinstance(value, (int, float)):
                total += int(value)
        return total


def cleanup_chunk_file(chunk_path: str) -> None:
    if os.path.exists(chunk_path):
        os.remove(chunk_path)
