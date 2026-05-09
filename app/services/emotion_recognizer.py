import torch
from transformers import AutoImageProcessor, AutoModelForImageClassification,AutoConfig
from PIL import Image
import cv2
import matplotlib.pyplot as plt

class EmotionRecognizer:
    def __init__(self):
        config = AutoConfig.from_pretrained("koyelog/face")
        self.device = "cuda" if torch.cuda.is_available() else "cpu"

        # Load processor and model from Hugging Face
        self.processor = AutoImageProcessor.from_pretrained("koyelog/face")
        self.model = AutoModelForImageClassification.from_pretrained("koyelog/face",
    low_cpu_mem_usage=True, # Reduces RAM spike during loading
    torch_dtype="auto"      # Allows Torch to choose the most efficient format
)
        self.model.to(self.device)
        self.model.eval()

        self.labels = self.model.config.id2label

    def predict(self, face_img):
        # Check if the image is valid
        if face_img is None or face_img.size == 0:
            return {"None": 1.0}

        # Convert BGR (OpenCV) to RGB (PIL expects RGB)
        img_rgb = cv2.cvtColor(face_img, cv2.COLOR_BGR2RGB)
        img = Image.fromarray(img_rgb)

        # Process image and convert to tensors
        inputs = self.processor(images=img, return_tensors="pt").to(self.device)

        # Get model predictions without gradient computation
        with torch.no_grad():
            outputs = self.model(**inputs)

        # Convert logits to probabilities
        probs = torch.nn.functional.softmax(outputs.logits, dim=1)[0]

        # Map probabilities to emotion labels
        result = {self.labels[i]: float(probs[i].item()) for i in range(len(probs))}

        return result

