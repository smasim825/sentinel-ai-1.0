# Sentinel Safety Ecosystem Guide 🛡️⌚

This document provides a technical overview of how the Sentinel SOS system operates across different hardware layers, including Mobile Phones, Smartwatches, and dedicated IoT Wristbands.

---

## 📱 1. The Mobile App Layer (The Brain)
The smartphone acts as the central command center for the Sentinel ecosystem.

### How it triggers:
*   **Manual**: On-screen SOS Button.
*   **Gesture**: System-level Accelerometer monitoring for a high-intensity "Panic Shake."
*   **Voice**: Background Microphone monitoring using **Speech-to-Text (STT)** to identify emergency keywords (e.g., "Bachao", "Sentinel Help").

### The Background Logic:
1.  **Detection**: A trigger is identified.
2.  **Countdown**: A 5-second grace period starts (with haptic vibration) to prevent false alarms.
3.  **Activation**:
    *   **GPS Tracking**: Precise location is polled every 5 meters.
    *   **Audio Evidence**: A 7-second high-fidelity ambient recording is captured.
    *   **Multi-Channel Alert**: Firebase Cloud Functions trigger **Twilio Voice Calls** and SMS messages to all saved guardians simultaneously.

---

## ⌚ 2. The Smartwatch Layer (Independent & Integrated)
Sentinel supports two modes for smartwatches (Apple Watch / WearOS).

### Mode A: Integrated (Companion Mode)
*   **Connectivity**: Bluetooth Low Energy (BLE).
*   **Function**: The watch acts as a remote sensor. It sends **Heart Rate (BPM)** and **Movement Data** to the phone app for calculation.
*   **Advantage**: Saves phone battery by offloading sensor polling to the wearable.

### Mode B: Independent (Standalone Mode)
*   **Requirement**: LTE/Cellular Smartwatch.
*   **Function**: If the user’s phone is lost, stolen, or broken, the watch app runs its own instance of the Sentinel logic. 
*   **Safety**: It uses its own built-in SIM card to send location data and alerts directly to the Firebase server without needing the phone.

---

## 📿 3. The IoT Wristband Layer (The Peripheral Trigger)
Specifically designed for discreet, long-life protection.

### How it works:
1.  **Hardware**: A low-power IoT device equipped with a physical panic button and **GSR (Galvanic Skin Response)** sensors.
2.  **Logic**: It communicates with the Sentinel Mobile App via **BLE (Bluetooth Low Energy)**.
3.  **Signal Fusion**: The wristband sends data packets containing:
    *   **Pulse Spikes**: Rapid heart rate changes.
    *   **Skin Conductance**: Moisture/stress detection (Sweat response).
    *   **Physical Press**: A discreet button click under the sleeve.

---

## 🧠 4. The "Dual-Confirmation" Logic (2-out-of-4)
To ensure the highest reliability for emergency responders, Sentinel uses a sophisticated **Sensor Fusion Algorithm**.

The app monitors 4 specific "Danger Signals":
1.  **Heart Rate Spike** (>120 BPM detected via wearable)
2.  **Voice Keyword** ("Help" detected via phone mic)
3.  **Skin Conductance Spike** (Stress detected via wristband)
4.  **Panic Shake** (Violent movement detected via wristband/phone)

### The Decision Matrix:
*   **1 Signal**: System enters "Yellow Alert" (Silent background monitoring).
*   **2+ Signals**: **SOS TRIGGERED**. Sentinel assumes a high-probability emergency and immediately initiates the full alert sequence.

---
**Sentinel Safety: Protection that follows you, wherever you go.**
