from dataclasses import dataclass
from typing import Optional
import io, wave
import numpy as np
from piper import PiperVoice

def _detect_lang(text: str) -> str:
    """
    TIMING & CONTEXT LOGIC:
    Checks if the input text contains Arabic characters to switch 
    to the appropriate localized voice model.
    """
    for ch in text:
        if "\u0600" <= ch <= "\u06FF" or "\u0750" <= ch <= "\u077F" or "\u08A0" <= ch <= "\u08FF":
            return "ar"
    return "en"

@dataclass
class TTSResult:
    audio_bytes: bytes
    mime_type: str = "audio/wav"
    sample_rate: Optional[int] = None

class TTSService:
    def __init__(self, voice_path: str, ar_voice_path: Optional[str] = None):
        # Load the default (English) and optional Arabic voices
        self.voice = PiperVoice.load(voice_path)
        self.ar_voice = PiperVoice.load(ar_voice_path) if ar_voice_path else None

    def synthesize(self, text: str) -> TTSResult:
        lang = _detect_lang(text)
        # Dynamic switching based on detected language
        voice = self.ar_voice if (lang == "ar" and self.ar_voice) else self.voice

        audio_iter = voice.synthesize(text)

        pcm_parts = []
        # Fallback sample rate if not found in config
        sample_rate = getattr(voice.config, "sample_rate", 22050)

        for chunk in audio_iter:
            # Handle different Piper output formats (bytes vs array)
            if hasattr(chunk, "audio_int16_bytes") and chunk.audio_int16_bytes:
                pcm_parts.append(chunk.audio_int16_bytes)
            else:
                pcm_parts.append(chunk.audio_int16_array.tobytes())

            if hasattr(chunk, "sample_rate") and chunk.sample_rate:
                sample_rate = int(chunk.sample_rate)

        pcm16 = b"".join(pcm_parts)

        # Build the WAV file in memory
        buf = io.BytesIO()
        with wave.open(buf, "wb") as wf:
            wf.setnchannels(1)  # Mono
            wf.setsampwidth(2) # 16-bit
            wf.setframerate(sample_rate)
            wf.writeframes(pcm16)

        return TTSResult(
            audio_bytes=buf.getvalue(), 
            mime_type="audio/wav", 
            sample_rate=sample_rate
        )