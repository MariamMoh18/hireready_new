from app.services.audio.TTS import TTSService

tts = TTSService("voices\en_US-amy-medium.onnx",
    ar_voice_path="voices/ar_JO-kareem-low.onnx"
    )
res = tts.synthesize("hey how are you")

with open("tts_test.wav", "wb") as f:
    f.write(res.audio_bytes)

print("Saved tts_test.wav | sample_rate =", res.sample_rate)