# Realtime Interview Pipeline

## Target flow

1. Frontend records webcam and microphone with `MediaRecorder`.
2. Every 3-5 seconds the client uploads a chunk to `POST /sessions/<session_id>/chunks`.
3. Backend stores the chunk temporarily and runs:
   - transcription through shared Whisper
   - audio behavioral extraction
   - sampled frame analysis through shared MediaPipe/HuggingFace services
4. Chunk metrics are persisted in `BehavioralMetricChunk`.
5. Answer-level aggregates are refreshed in `Answer`.
6. Session-level rolling state is refreshed in `InterviewSession.analysis_results["realtime"]`.
7. Existing final scoring still runs from `Answer` rows during `/finalize`.

## Why this shape

- It preserves your current `Answer -> Feedback -> Score` lifecycle.
- It adds chunk-level observability without forcing a LangGraph rewrite.
- It avoids loading CV and STT models per request.
- It keeps the system open for later async workers or websockets.

## Recommended next backend step

- Move `RealtimeChunkPipeline.process_video_chunk_file(...)` behind a job queue for heavier concurrency.
- Add a dedicated calibration endpoint that stores `session.master_baseline` from a short neutral clip before question one.
- Split browser uploads into separate `audio/webm` and `video/webm` tracks if transcription quality or decode reliability becomes inconsistent.

## Recommended folder structure

```text
app/
  routes/
    sessions.py
  services/
    model_registry.py
    video_pipeline.py
    feedback_generator.py
    scoring_service.py
    audio/
      STT.py
      audio_chunk_analyzer.py
    realtime/
      chunk_pipeline.py
  Mind/
    graph.py
    state.py
docs/
  realtime_interview_pipeline.md
```
