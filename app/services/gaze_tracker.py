import cv2 as cv
import numpy as np
import mediapipe as mp
#using mediapipe to track the gaze of the user
class GazeTracker:
    def __init__(self):
        self.mp_face_mesh = mp.solutions.face_mesh
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            static_image_mode=False,
            max_num_faces=1,
            refine_landmarks=True, # Critical for iris detection
            min_detection_confidence=0.5
        )
        
        # Landmark indices for eyes
        self.LEFT_EYE = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398]
        self.RIGHT_EYE = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
        self.LEFT_IRIS = [474, 475, 476, 477]
        self.RIGHT_IRIS = [469, 470, 471, 472]

    def get_gaze_ratio(self, landmarks, frame):
        # Calculate horizontal gaze ratio for the left eye
        # 0.5 is center, < 0.35 is Right, > 0.65 is Left
        def get_eye_ratio(eye_points, iris_points):
            # Eye corners
            left_corner = np.array([landmarks[eye_points[0]].x, landmarks[eye_points[0]].y])
            right_corner = np.array([landmarks[eye_points[8]].x, landmarks[eye_points[8]].y])
            
            # Iris center
            iris_center = np.mean([[landmarks[i].x, landmarks[i].y] for i in iris_points], axis=0)
            
            # Distance from left corner to iris / total eye width
            eye_width = np.linalg.norm(left_corner - right_corner)
            iris_pos = np.linalg.norm(left_corner - iris_center)
            
            return iris_pos / eye_width if eye_width != 0 else 0.5

        left_ratio = get_eye_ratio(self.LEFT_EYE, self.LEFT_IRIS)
        right_ratio = get_eye_ratio(self.RIGHT_EYE, self.RIGHT_IRIS)
        
        return (left_ratio + right_ratio) / 2

    def is_looking_at_camera(self, frame):
        rgb_frame = cv.cvtColor(frame, cv.COLOR_BGR2RGB)
        results = self.face_mesh.process(rgb_frame)
        
        if not results.multi_face_landmarks:
            return False, 0.5
        
        landmarks = results.multi_face_landmarks[0].landmark
        ratio = self.get_gaze_ratio(landmarks, frame)
        
        # Thresholds: 0.4 to 0.6 is roughly "Center/Camera"
        is_centered = 0.38 <= ratio <= 0.62
        return is_centered, ratio