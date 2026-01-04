import cv2
import numpy as np
import os
import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

DATASET_DIR = "dataset"
OUT_DIR = "pose_data"
os.makedirs(OUT_DIR, exist_ok=True)

# Load pose landmarker (IMAGE mode – no timestamps needed)
base_options = mp_python.BaseOptions(
    model_asset_path="pose_landmarker_heavy.task"
)

options = vision.PoseLandmarkerOptions(
    base_options=base_options,
    running_mode=vision.RunningMode.IMAGE,
    num_poses=1
)

pose = vision.PoseLandmarker.create_from_options(options)

def process_video(video_path):
    cap = cv2.VideoCapture(video_path)
    seq = []

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        mp_image = mp.Image(
            image_format=mp.ImageFormat.SRGB,
            data=frame_rgb
        )

        result = pose.detect(mp_image)

        if result.pose_landmarks:
            frame_landmarks = []
            for lm in result.pose_landmarks[0]:
                frame_landmarks.extend([lm.x, lm.y, lm.z])
            seq.append(frame_landmarks)

    cap.release()
    return np.array(seq, dtype=np.float32)

for label in ["normal", "seizure"]:
    in_dir = os.path.join(DATASET_DIR, label)
    out_dir = os.path.join(OUT_DIR, label)
    os.makedirs(out_dir, exist_ok=True)

    for vid in os.listdir(in_dir):
        if vid.endswith(".mp4"):
            data = process_video(os.path.join(in_dir, vid))
            if len(data) > 0:
                np.save(
                    os.path.join(out_dir, vid.replace(".mp4", ".npy")),
                    data
                )

print("Pose extraction done.")
