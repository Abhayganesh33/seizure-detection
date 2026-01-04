import cv2
import numpy as np
import tkinter as tk
from tkinter import filedialog

# ---------- Pick video file ----------
root = tk.Tk()
root.withdraw()
video_path = filedialog.askopenfilename(
    title="Select seizure video",
    filetypes=[("Video files", "*.mp4 *.avi *.mov")]
)

if not video_path:
    print("No video selected")
    exit()

cap = cv2.VideoCapture(video_path)

prev_gray = None
motion_signal = []

# ---- Window & FPS ----
MAX_LEN = 90                      # ~3 sec window
FPS = cap.get(cv2.CAP_PROP_FPS)
FPS = FPS if FPS > 0 else 30

# ---- Detection parameters (realistic) ----
MOTION_THRESHOLD = 1e6            # window-average motion
FREQ_LOW = 0.5
FREQ_HIGH = 18.0
DURATION_SEC = 0.3                # short for video testing

required_frames = int(DURATION_SEC * FPS)
seizure_frames = 0
seizure_detected = False

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

    # ---- Build motion signal ----
    motion_signal.append(motion_value)
    if len(motion_signal) > MAX_LEN:
        motion_signal.pop(0)

    dominant_freq = 0
    avg_motion = 0

    if len(motion_signal) == MAX_LEN:
        signal = np.array(motion_signal)
        avg_motion = np.mean(signal)

        # ---- Spectral analysis ----
        signal = signal - np.mean(signal)
        fft_vals = np.abs(np.fft.rfft(signal))
        freqs = np.fft.rfftfreq(len(signal), d=1 / FPS)
        dominant_freq = freqs[np.argmax(fft_vals)]

        # ---- Window-based condition (KEY FIX) ----
        condition = (
            avg_motion > MOTION_THRESHOLD and
            FREQ_LOW <= dominant_freq <= FREQ_HIGH
        )

        if condition:
            seizure_frames += 1
            if seizure_frames >= required_frames:
                seizure_detected = True
        else:
            seizure_frames = 0
            seizure_detected = False

    # ---- UI ----
    cv2.putText(frame, f"Avg Motion: {int(avg_motion)}", (20, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

    cv2.putText(frame, f"Freq: {dominant_freq:.2f} Hz", (20, 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 0, 0), 2)

    if seizure_detected:
        cv2.putText(frame, "SEIZURE-LIKE ACTIVITY DETECTED",
                    (20, 130),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.9,
                    (0, 0, 255),
                    3)

    cv2.imshow("Seizure Video Analysis", frame)

    if cv2.waitKey(30) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
