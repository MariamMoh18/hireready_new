from datetime import datetime
import io
import os
import sys
import threading
import time
import wave

import cv2
import keyboard
import numpy as np
import sounddevice as sd
from dotenv import load_dotenv

# =========================
# Environment Setup
# =========================
load_dotenv()

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"

# =========================
# Path Setup
# =========================
sys.path.insert(
    0,
    os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
)

# =========================
# Flask App
# =========================
from app import create_app
from app.models import InterviewSession, db

flask_app = create_app()

# =========================
# Imports Inside App Context
# =========================
with flask_app.app_context():
    from app.Mind.graph import build_graph
    from app.services.audio.STT import STTService
    from app.services.audio.TTS import TTSService
    from app.services.model_registry import get_video_processor
    from app.services.scoring_service import ScoringSystem

# =========================
# Global Services
# =========================
graph = build_graph()
tts = TTSService(voice_path="voices\en_GB-alba-medium.onnx")
stt = STTService(model_size="small", device="cpu", compute_type="int8")
video_processor = get_video_processor()

# =========================
# Constants
# =========================
SAMPLE_RATE = 16000

# =========================
# Camera Setup
# =========================
global_cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)

if not global_cap.isOpened():
    raise RuntimeError("❌ Could not access webcam.")

actual_width = int(global_cap.get(cv2.CAP_PROP_FRAME_WIDTH))
actual_height = int(global_cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

# =========================
# Thread Tracking
# =========================
active_threads = []

# =========================
# TTS
# =========================
def speak(text_to_say: str):
    if not text_to_say:
        return
    try:
        result = tts.synthesize(text_to_say)
        audio_array = np.frombuffer(result.audio_bytes, dtype=np.int16)
        sd.play(audio_array, samplerate=result.sample_rate)
        sd.wait()
    except Exception as e:
        print(f"❌ TTS Error: {e}")

# =========================
# WAV Conversion
# =========================
def audio_frames_to_wav_bytes(audio_frames):
    if not audio_frames:
        raise ValueError("No audio frames captured.")
    recording = np.concatenate(audio_frames, axis=0)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(recording.tobytes())
    return buf.getvalue()

# =========================
# Recording
# =========================
def record_audio_video(cap):
    print("🔴 Recording... (Hold SPACE)")

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    video_filename = f"temp_{int(time.time())}.mp4"
    out_video = cv2.VideoWriter(
        video_filename, fourcc, 20.0,
        (actual_width, actual_height)
    )

    audio_frames = []
    stream = sd.InputStream(samplerate=SAMPLE_RATE, channels=1, dtype="int16")
    stream.start()

    window_name = "Interview in Progress"
    frame_count = 0

    while keyboard.is_pressed("space"):
        audio_chunk, _ = stream.read(1024)
        audio_frames.append(audio_chunk.copy())
        ret, frame = cap.read()
        if ret:
            out_video.write(frame)
            frame_count += 1
            cv2.imshow(window_name, frame)
            cv2.waitKey(1)

    stream.stop()
    stream.close()
    out_video.release()

    try:
        cv2.destroyWindow(window_name)
    except:
        pass

    while keyboard.is_pressed("space"):
        time.sleep(0.05)

    return video_filename, audio_frames

# =========================
# Background Worker
# =========================
def background_worker(video_file, audio_frames, session_id, question_text, answer_text):
    try:
        print("🧠 Processing AI analysis...")

        if os.path.exists(video_file) and os.path.getsize(video_file) > 10000:
            metrics = video_processor.process_video(
                video_file,
                master_baseline=baseline
            )
        else:
            print("⚠️ Video file too small, using default metrics")
            metrics = {
                "confidence": 50,
                "eye_contact_score": 50,
                "stress": 0,
                "engagement": 50
            }

        with flask_app.app_context():
            from app.models import Answer
            from app.services.feedback_generator import FeedbackGenerator

            new_ans = Answer(
                session_id=session_id,
                answer_text=answer_text,
                facial_confidence=metrics.get("confidence", 50),
                eye_contact_percentage=metrics.get("eye_contact_score", 50),
                stress_level=metrics.get("stress", 0),
                engagement_score=metrics.get("engagement", 50)
            )
            db.session.add(new_ans)
            db.session.commit()

            FeedbackGenerator.generate_and_save(
                answer_id=new_ans.id,
                transcript=answer_text,
                question_text=question_text,
                behavioral_results=metrics
            )
            print(f"✅ Answer saved (id={new_ans.id})")

    except Exception as e:
        print(f"❌ Background Worker Error: {e}")

    finally:
        with flask_app.app_context():
            db.session.remove()
        if os.path.exists(video_file):
            os.remove(video_file)

# =========================
# Calibration
# =========================
def calibrate(cap, session_id):
    print("\n--- 🛡️ Calibration Phase ---")
    print("Please look neutrally at the camera.")
    speak("Please look at the camera neutrally for three seconds.")

    calib_data = []
    start_time = time.time()

    try:
        while time.time() - start_time < 3:
            ret, frame = cap.read()
            if ret:
                cv2.imshow("Calibrating...", frame)
                cv2.waitKey(1)
                faces = video_processor.face_detector.detect(frame)
                for face_data in faces:
                    probs = video_processor.emotion_recognizer.predict(face_data["crop"])
                    calib_data.append(probs)
            time.sleep(0.01)
    finally:
        try:
            cv2.destroyWindow("Calibrating...")
        except:
            pass

    baseline = (
        video_processor.calculate_baseline(calib_data)
        if calib_data
        else {emo: 0.0 for emo in video_processor.labels.values()}
    )

    with flask_app.app_context():
        session = db.session.get(InterviewSession, session_id)
        if session:
            session.master_baseline = baseline
            db.session.commit()

    print("✅ Calibration Complete.")
    return baseline

# =========================
# Create Session
# =========================
with flask_app.app_context():
    from app.models import User, JobPosition, AIModel

    user = User.query.first()
    if not user:
        raise RuntimeError("❌ No user found in DB.")

    job = JobPosition.query.get(1)  # ← change to whichever job id you want
    if not job:
        raise RuntimeError("❌ No job position found in DB.")

    ai_model = AIModel.query.order_by(AIModel.created_at.desc()).first()

    # --- change mode here ---
    MODE = "quick"     # quick / standard / full
    MODE_MAP = {"quick": 4, "standard": 8, "full": 13}

    session = InterviewSession(
        user_id=user.id,
        job_position_id=job.id,
        ai_model_id=ai_model.id if ai_model else None,
        status="in_progress",
        session_type=MODE,
        max_questions=MODE_MAP[MODE],
    )
    db.session.add(session)
    db.session.commit()

    session_db_id = session.id

    job_context = {
        "job_title": job.title,
        "job_level": job.level or "",
        "job_skills": [skill.name for skill in job.skills],
    }

# =========================
# Calibration
# =========================
baseline = calibrate(global_cap, session_db_id)

# =========================
# Initial State
# =========================
state = {
    "session_id": session_db_id,
    "messages": [],
    "question_count": 0,
    "max_questions": MODE_MAP[MODE],   # ← driven by MODE, one place to change
    "current_question": None,
    "pending_answer": None,
    "master_baseline": baseline,
    "current_answer_id": None,
    "current_behavioral_metrics": None,
    "current_partial_transcript": None,
    "answer_processing_status": "idle",
    "last_chunk_index": None,
    "is_finished": False,
    **job_context,
}

print(f"\n=== Interview Mode: {MODE.upper()} | {job_context['job_title']} ({job_context['job_level']}) ===")
print(f"Questions: {MODE_MAP[MODE]}\n")

# =========================
# Main Interview Loop
# =========================
try:
    while not state.get("is_finished"):

        # --- check if done BEFORE asking next question ---
        if state["question_count"] >= state["max_questions"]:
            break

        # --- generate next question ---
        out = graph.invoke(state)
        state = {**state, **out}   # ← proper merge

        if state.get("is_finished"):
            break

        current_question = state.get("current_question")

        if current_question:
            print(f"\n🤖 AI:\n{current_question}\n")
            speak(current_question)

        # --- wait for user ---
        print("🎙️ Hold SPACE to answer | ⛔ ESC to exit")

        while True:
            if keyboard.is_pressed("esc"):
                print("⛔ Interview terminated.")
                state["is_finished"] = True
                break

            if keyboard.is_pressed("space"):
                video_file, audio_frames = record_audio_video(global_cap)

                if not audio_frames:
                    print("⚠️ No audio captured, try again.")
                    continue

                total_samples = sum(len(f) for f in audio_frames)
                if total_samples < SAMPLE_RATE * 0.3:
                    print("⚠️ Too short, hold SPACE longer.")
                    continue

                # --- STT ---
                try:
                    wav_bytes = audio_frames_to_wav_bytes(audio_frames)
                    answer_text = stt.transcribe(wav_bytes).text.strip()
                    print(f"✅ YOU: '{answer_text}'")
                except Exception as e:
                    print(f"⚠️ STT Error: {e}")
                    answer_text = ""

                # --- update state ---
                if answer_text:
                    state["messages"].append({"role": "user", "content": answer_text})

                state["question_count"] += 1

                if state["question_count"] >= state["max_questions"]:
                    state["is_finished"] = True

                # --- background video + DB save ---
                worker = threading.Thread(
                    target=background_worker,
                    args=(
                        video_file,
                        audio_frames,
                        session_db_id,
                        current_question or "Interview Question",
                        answer_text,
                    ),
                    daemon=True,
                )
                worker.start()
                active_threads.append(worker)
                break

            time.sleep(0.05)

# =========================
# Cleanup
# =========================
finally:
    print("\n⏳ Cleaning up...")
    global_cap.release()
    cv2.destroyAllWindows()

    print("🧠 Finishing background tasks...")
    for worker in active_threads:
        worker.join()

    speak("Thank you for your time. Please wait while I prepare your feedback.")

    with flask_app.app_context():
        db.session.expire_all()
        print("📊 Generating final report...")

        try:
            ScoringSystem.process_and_save_final_score(session_db_id)
            print("✅ Report generated.")

            session = db.session.get(InterviewSession, session_db_id)
            if session:
                session.status = "completed"
                session.end_time = datetime.now()
                session.duration = int(
                    (session.end_time - session.start_time).total_seconds()
                )
                db.session.commit()
                print("✅ Session marked as completed.")

        except Exception as e:
            print(f"❌ Final scoring error: {e}")

        finally:
            db.session.remove()

    print("👋 Interview session completed.")