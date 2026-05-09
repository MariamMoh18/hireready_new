import cv2
import mediapipe as mp

class MediaPipeFaceDetector:
    def __init__(self):
        self.mp_face = mp.solutions.face_detection
        # model_selection=0 is optimized for faces within 2 meters of the camera (perfect for interviews)
        self.detector = self.mp_face.FaceDetection(model_selection=0, min_detection_confidence=0.5)
       
    def detect(self, frame):
        h, w, _ = frame.shape
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self.detector.process(rgb)

        faces_data = []

        if results.detections:
            for detection in results.detections:
                bbox = detection.location_data.relative_bounding_box

                # Convert relative coordinates to pixel coordinates
                x = max(0, int(bbox.xmin * w))
                y = max(0, int(bbox.ymin * h))
                width = int(bbox.width * w)
                height = int(bbox.height * h)

                #  Crop the face for the emotion model
                face_crop = frame[y:y+height, x:x+width]
                
                #  Store coordinates and the cropped image
                faces_data.append({
                    "box": (x, y, width, height),
                    "crop": face_crop
                })

        return faces_data