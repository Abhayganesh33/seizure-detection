Seizure Detection System

This project focuses on detecting seizure activity using human pose analysis and deep learning, with a Flutter-based mobile application for real-time and offline monitoring.

Project Overview

The system was initially explored using rule-based motion and frequency analysis but was later redesigned to use a fully machine-learning-driven approach for improved reliability and accuracy. The final solution runs entirely on-device without server dependency.

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

Videos aligned, cleaned, and segmented into fixed 5-second clips

Pose extraction pipeline implemented using MediaPipe

Pose data converted into .npy sequences

4. Machine Learning Model (Final Approach)

Switched completely from Flask + FFT logic to a custom ML model

Staged dataset created from pose sequences

LSTM model trained on temporal pose data

Trained model saved as .h5

Model converted to TensorFlow Lite (.tflite) for mobile inference

5. Mobile Application

Flutter mobile application developed using Android Studio

Live camera integration implemented

On-device inference enabled using TFLite

Backend dependency removed for offline usage

Methodology

Camera captures live video

Pose detection extracts body joint landmarks

Motion sequences are analyzed over time

LSTM model classifies movements as normal or seizure-like

Inference runs fully on-device using TensorFlow Lite

Key Features

Real-time monitoring

Offline AI inference

Pose skeleton visualization

Motion intensity graph

Seizure history logging

PDF report export

Adjustable detection sensitivity

Tech Stack

Python, OpenCV

MediaPipe for pose estimation

TensorFlow / Keras (LSTM)

TensorFlow Lite

Flutter (Android)

Goal

To provide a reliable, low-latency seizure detection system that operates fully on-device, enabling continuous monitoring even without internet connectivity.