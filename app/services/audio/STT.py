from dataclasses import dataclass, field
from typing import Optional, List
import io
import numpy as np
import soundfile as sf
from faster_whisper import WhisperModel

@dataclass
class WordSegment:
    start: float
    end: float
    text: str

@dataclass
class STTResult:
    text: str
    language: Optional[str] = None
    segments: List[WordSegment] = field(default_factory=list) # Added for segmentation link

class STTService:
    def __init__(self, model_size: str = "small", device: str = "cpu", compute_type: str = "int8"):
        self.model = WhisperModel(model_size, device=device, compute_type=compute_type)

    def transcribe(self, audio_bytes: bytes) -> STTResult:
        audio, sr = sf.read(io.BytesIO(audio_bytes), dtype="float32", always_2d=True)
        audio = np.mean(audio, axis=1)

        # word_timestamps=True allows us to see exactly when words were spoken
        segments, info = self.model.transcribe(audio, language="en", beam_size=5, vad_filter=True)
        
        full_text = []
        captured_segments = []

        for seg in segments:
            full_text.append(seg.text.strip())
            captured_segments.append(WordSegment(
                start=round(seg.start, 2),
                end=round(seg.end, 2),
                text=seg.text.strip()
            ))

        return STTResult(
            text=" ".join(full_text).strip(),
            language=info.language,
            segments=captured_segments
        )