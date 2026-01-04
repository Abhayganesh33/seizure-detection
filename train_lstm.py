import os
import numpy as np
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.preprocessing.sequence import pad_sequences
from sklearn.model_selection import train_test_split

DATA_DIR = "pose_data"
MAX_TIMESTEPS = 75   # ~5 sec at ~15 FPS
NUM_FEATURES = 99    # 33 landmarks × (x,y,z)

X = []
y = []

def load_class(folder, label):
    for f in os.listdir(folder):
        if f.endswith(".npy"):
            arr = np.load(os.path.join(folder, f))
            X.append(arr)
            y.append(label)

load_class(os.path.join(DATA_DIR, "normal"), 0)
load_class(os.path.join(DATA_DIR, "seizure"), 1)

X = pad_sequences(X, maxlen=MAX_TIMESTEPS, dtype="float32", padding="post", truncating="post")
y = np.array(y)

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

model = Sequential([
    LSTM(64, input_shape=(MAX_TIMESTEPS, NUM_FEATURES)),
    Dropout(0.3),
    Dense(1, activation="sigmoid")
])

model.compile(
    optimizer="adam",
    loss="binary_crossentropy",
    metrics=["accuracy"]
)

model.summary()

model.fit(
    X_train, y_train,
    epochs=25,
    batch_size=8,
    validation_data=(X_test, y_test)
)

model.save("seizure_lstm.h5")
print("Model saved as seizure_lstm.h5")
