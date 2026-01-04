from flask import Flask, jsonify, request
from flask_cors import CORS
import cv2
import numpy as np
import os

app = Flask(__name__)
CORS(app)

VIDEO_FOLDER = "videos"

# ---- Detection parameters ----
MAX_LEN = 90
MOTION_THRESHOLD = 1e6
FREQ_LOW = 0.5
FREQ_HIGH = 18.0
DURATION_SEC = 0.3


@app.route("/", methods=["GET"])
def home():
    return jsonify({"message": "API running"})


# ✅ NEW: simple frame-based test endpoint (for Flutter)
@app.route("/analyze", methods=["POST"])
def analyze_frames():
    data = request.get_json()

    if not data or "frames" not in data:
        return jsonify({"error": "frames missing"}), 400

    frames = np.array(data["frames"], dtype=np.float32)
    avg_motion = float(np.mean(frames))
    seizure_detected = avg_motion > 10  # dummy threshold (test only)

    return jsonify({
        "avg_motion": avg_motion,
        "frames_count": len(frames),
        "seizure_detected": seizure_detected
    })


@app.route("/analyze_video", methods=["POST"])
def analyze_video():
    data = request.get_json()

    if not data or "filename" not in data:
        return jsonify({"error": "filename missing"}), 400

    video_path = os.path.join(VIDEO_FOLDER, data["filename"])
    if not os.path.exists(video_path):
        return jsonify({"error": "video not found"}), 404

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        return jsonify({"error": "cannot open video"}), 500

    FPS = cap.get(cv2.CAP_PROP_FPS)
    FPS = FPS if FPS > 0 else 30
    required_frames = int(DURATION_SEC * FPS)

    prev_gray = None
    motion_signal = []
    seizure_frames = 0
    seizure_detected = False
    dominant_freq = 0
    avg_motion = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (21, 21), 0)

        motion_value = 0
        if prev_gray is not None:
            diff = cv2.absdiff(prev_gray, gray)
            motion_value = int(np.sum(diff))

        prev_gray = gray
        motion_signal.append(motion_value)

        if len(motion_signal) > MAX_LEN:
            motion_signal.pop(0)

        if len(motion_signal) == MAX_LEN:
            signal = np.array(motion_signal)
            avg_motion = float(np.mean(signal))

            centered = signal - np.mean(signal)
            fft_vals = np.abs(np.fft.rfft(centered))
            freqs = np.fft.rfftfreq(len(centered), d=1 / FPS)
            dominant_freq = float(freqs[np.argmax(fft_vals)])

            if avg_motion > MOTION_THRESHOLD and FREQ_LOW <= dominant_freq <= FREQ_HIGH:
                seizure_frames += 1
                if seizure_frames >= required_frames:
                    seizure_detected = True
            else:
                seizure_frames = 0
                seizure_detected = False

    cap.release()

    return jsonify({
        "video": data["filename"],
        "avg_motion": int(avg_motion),
        "dominant_freq": round(dominant_freq, 2),
        "seizure_detected": bool(seizure_detected)
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
