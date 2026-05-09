from app.services.audio.STT import STTService

def main():
    stt = STTService(model_size="small", device="cpu", compute_type="int8")

    with open("tts_test.wav", "rb") as f:
        audio_bytes = f.read()

    res = stt.transcribe(audio_bytes, mime_type="audio/wav")
    print("LANG:", res.language)
    print("TEXT:", res.text)

if __name__ == "__main__":
    main()