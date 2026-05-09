from __future__ import annotations

from dataclasses import asdict
from typing import Any

from app.services.audio.STT import STTResult


class AudioChunkAnalyzer:
    """Derives lightweight chunk-level audio and speech metrics from STT output."""

    FILLER_WORDS = {
        "um",
        "uh",
        "like",
        "actually",
        "basically",
        "literally",
    }

    def analyze(self, stt_result: STTResult, chunk_duration_ms: int | None = None) -> dict[str, Any]:
        text = (stt_result.text or "").strip()
        tokens = [token.strip(".,!?;:").lower() for token in text.split() if token.strip()]
        word_count = len(tokens)

        if stt_result.segments:
            speech_duration_seconds = max(
                0.0,
                stt_result.segments[-1].end - stt_result.segments[0].start,
            )
        elif chunk_duration_ms:
            speech_duration_seconds = chunk_duration_ms / 1000.0
        else:
            speech_duration_seconds = 0.0

        words_per_minute = 0.0
        if speech_duration_seconds > 0:
            words_per_minute = (word_count / speech_duration_seconds) * 60.0

        filler_count = sum(1 for token in tokens if token in self.FILLER_WORDS)

        return {
            "transcript": text,
            "language": stt_result.language,
            "word_count": word_count,
            "words_per_minute": round(words_per_minute, 2),
            "filler_count": filler_count,
            "duration_ms": round(speech_duration_seconds * 1000),
            "segments": [asdict(segment) for segment in stt_result.segments],
        }

