import os
import sys
import cv2


class VideoProcessor:
    def __init__(self):
        from app.services.facial_analyzer import MediaPipeFaceDetector
        from app.services.emotion_recognizer import EmotionRecognizer
        from app.services.gaze_tracker import GazeTracker

        self.face_detector = MediaPipeFaceDetector()
        self.emotion_recognizer = EmotionRecognizer()
        self.gaze_tracker = GazeTracker()
        self.labels = self.emotion_recognizer.labels

    def calculate_baseline(self, frames_data):
        if not frames_data:
            return {label: 0.0 for label in self.labels.values()}

        emotions = frames_data[0].keys()
        return {
            emo: sum(f.get(emo, 0) for f in frames_data) / len(frames_data)
            for emo in emotions
        }

    def translate_to_metrics(self, raw_averages, gaze_ratio, baseline=None):
        if baseline is None:
            baseline = {emo: 0.0 for emo in raw_averages.keys()}

        calibrated = {
            emo: max(0, raw_averages.get(emo, 0) - baseline.get(emo, 0))
            for emo in raw_averages.keys()
        }

        raw_conf = (raw_averages.get('neutral', 0) * 0.6) + (calibrated.get('happy', 0) * 0.4)
        fear_penalty = (calibrated.get('fear', 0) * 0.5) + (calibrated.get('anger', 0) * 0.3)

        confidence = (raw_conf - fear_penalty) * 100

        gaze_penalty = max(0, (60 - gaze_ratio) * 0.2)
        stress = (
            calibrated.get('fear', 0) * 0.6 +
            calibrated.get('anger', 0) * 0.3 +
            calibrated.get('sad', 0) * 0.1
        ) * 100 + gaze_penalty

        engagement = (
            calibrated.get('surprise', 0) * 0.7 +
            calibrated.get('happy', 0) * 0.3
        ) * 100

        return {
            "confidence": round(max(35, min(100, confidence + 15))),
            "stress": round(max(5, min(100, stress))),
            "eye_contact_score": round(max(0, min(100, gaze_ratio))),
            "engagement": round(max(20, min(100, engagement + 10)))
        }

    def process_video(self, video_path, master_baseline=None):
        cap = cv2.VideoCapture(video_path)

        if not cap.isOpened():
            return {"error": "Could not open video file"}

        fps = cap.get(cv2.CAP_PROP_FPS)
        sample_rate = max(1, int(fps / 2))

        calibration_limit = int(fps * 3)
        calibration_frames_data = []
        all_emotions_data = []

        eye_contact_frames = 0
        total_sampled_frames = 0
        frame_count = 0

        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            if frame_count % sample_rate == 0:
                total_sampled_frames += 1

                looking, _ = self.gaze_tracker.is_looking_at_camera(frame)
                if looking:
                    eye_contact_frames += 1

                faces = self.face_detector.detect(frame)
                for face_data in faces:
                    face_img = face_data["crop"]
                    prob_dict = self.emotion_recognizer.predict(face_img)

                    if frame_count < calibration_limit:
                        calibration_frames_data.append(prob_dict)
                    else:
                        all_emotions_data.append(prob_dict)

            frame_count += 1

        cap.release()

        if not all_emotions_data:
            return {"error": "No data collected after calibration"}

        if master_baseline is not None:
            user_baseline = master_baseline
        elif calibration_frames_data:
            user_baseline = self.calculate_baseline(calibration_frames_data)
        else:
            user_baseline = {emo: 0.0 for emo in self.labels.values()}

        final_averages = {
            emotion: sum(d[emotion] for d in all_emotions_data) / len(all_emotions_data)
            for emotion in self.labels.values()
        }

        gaze_percentage = (
            (eye_contact_frames / total_sampled_frames) * 100
            if total_sampled_frames > 0 else 0
        )

        return self.translate_to_metrics(
            final_averages,
            gaze_percentage,
            baseline=user_baseline
        )
