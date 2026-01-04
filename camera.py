import cv2
import numpy as np
import time

cap = cv2.VideoCapture(0)

prev_gray = None
motion_signal = []
MAX_LEN = 90          # ~3 sec buffer
FPS = 30

# ---- VERY LOW thresholds (demo mode) ----
MOTION_THRESHOLD = 2e5     # very sensitive
FREQ_LOW = 0.20            # Hz
FREQ_HIGH = 10.0           # Hz
DURATION_SEC = 0.5         # half second only

seizure_start = None
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

    motion_signal.append(motion_value)
    if len(motion_signal) > MAX_LEN:
        motion_signal.pop(0)

    dominant_freq = 0

    if len(motion_signal) == MAX_LEN:
        signal = np.array(motion_signal)
        signal = signal - np.mean(signal)

        fft_vals = np.abs(np.fft.rfft(signal))
        freqs = np.fft.rfftfreq(len(signal), d=1/FPS)

        dominant_freq = freqs[np.argmax(fft_vals)]

        condition = (
            motion_value > MOTION_THRESHOLD and
            FREQ_LOW <= dominant_freq <= FREQ_HIGH
        )

        if condition:
            if seizure_start is None:
                seizure_start = time.time()
            elif time.time() - seizure_start >= DURATION_SEC:
                seizure_detected = True
        else:
            seizure_start = None
            seizure_detected = False

    # ---- UI ----
    cv2.putText(frame, f"Motion: {motion_value}", (20, 40),
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

    cv2.imshow("Seizure Motion Monitor (Demo)", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
