Seizure Detection System

This project focuses on detecting seizure activity using human pose analysis and deep learning, with a Flutter-based mobile application for real-time, offline monitoring.

Project Overview

The system was initially explored using rule-based motion and frequency analysis but was later redesigned to use a fully machine-learning-driven approach for improved reliability and accuracy.
The final solution runs entirely on-device without any server or cloud dependency.

📁 Dataset / Demo:
https://drive.google.com/file/d/1zeNfm2ohGFMOdRMHdi9pjd0Cpctmg0TJ/view?usp=sharing

🎥 Reference Videos:
https://drive.google.com/drive/folders/16IUU2HXWjWC1dVlU_DOIcD9M9aC8Kpn-?usp=sharing

System Flowchart

Project Images








Development Timeline
1. Initial Setup

Repository initialized

Basic webcam video capture implemented

OpenCV and required dependencies added

Virtual environment excluded from version control

2. Initial Rule-Based Approach (Discarded)

Flask backend used for early testing

Motion-based detection and FFT frequency analysis implemented

Approach discontinued due to limited robustness

3. Dataset Preparation

Video dataset collected and organized (normal vs seizure)

Videos segmented into fixed 5-second clips

Pose extraction implemented using MediaPipe

Pose data converted into .npy sequences

4. Machine Learning Model (Final Approach)

Rule-based logic fully replaced with ML model

Temporal pose sequences used as input

LSTM model trained using TensorFlow/Keras

Trained model saved as .h5

Converted to TensorFlow Lite (.tflite) for mobile deployment

5. Mobile Application

Flutter application developed

Live camera integration implemented

On-device inference enabled using TFLite

Backend dependency removed for offline operation

Methodology

Camera captures live video

Pose detection extracts body joint landmarks

Landmark sequences are analyzed over time

LSTM model classifies motion as normal or seizure-like

All inference runs locally using TensorFlow Lite

Key Features

Real-time monitoring

Fully offline AI inference

Pose skeleton visualization

Motion intensity graph

Seizure history logging

PDF report export

Adjustable detection sensitivity

Tech Stack

Python, OpenCV

MediaPipe (Pose Estimation)

TensorFlow / Keras (LSTM)

TensorFlow Lite

Flutter (Android)

Goal

To provide a low-latency, privacy-preserving seizure detection system that operates entirely on-device, enabling continuous monitoring even without internet connectivity.