from functools import lru_cache


@lru_cache(maxsize=1)
def get_video_processor():
    """Shared video pipeline instance to avoid reloading AI models per request."""
    from app.services.video_pipeline import VideoProcessor
    return VideoProcessor()


@lru_cache(maxsize=1)
def get_stt_service():
    """Shared Whisper instance for answer and chunk ingestion flows."""
    from app.services.audio.STT import STTService
    return STTService(model_size="base", device="cpu", compute_type="int8")

