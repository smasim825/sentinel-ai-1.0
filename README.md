# Sentinel Safety 🛡️

**Empowering personal safety through real-time technology.**

Sentinel is a next-generation safety application designed to provide immediate assistance and peace of mind. Built with Flutter and powered by Firebase, it offers a suite of proactive security features for individuals and their guardians.

## 🚀 Key Features

*   **One-Tap & Shake SOS**: Trigger immediate emergency alerts with a single button or a simple shaking gesture.
*   **Voice-Activated Protection**: Detects distress keywords (like "Bachao" or "Help Sentinel") to activate alerts hands-free.
*   **Real-Time Guardian Tracking**: Live location sharing and interactive maps during an emergency.
*   **Ambient Audio Evidence**: Automatically records and shares a 7-second audio clip of the surroundings during an SOS event.
*   **Panic Fake Call**: Discreetly trigger a realistic-looking incoming call to excuse yourself from uncomfortable situations.
*   **Biometric Monitoring**: Integrated support for heart-rate monitoring and emergency wristband alerts.

## 🛠️ Technical Stack

*   **Frontend**: Flutter (Cross-platform Android/Web)
*   **Backend**: Firebase (Auth, Firestore, Cloud Functions, Storage)
*   **APIs**: Google Maps API, Twilio (Emergency Calls), EmailJS (OTP Verification)
*   **Hardware**: Motion Accelerometer, Microphone, GPS

## ⚙️ Setup & Configuration

Since sensitive credentials and project-specific keys are ignored under version control, you will need to add your own to run this application:

### 1. Google Maps API Key
Replace the placeholder `YOUR_GOOGLE_MAPS_API_KEY` with your actual key in the following files:
*   [web/index.html](file:///Users/smasim/Antigrav/sentinel/web/index.html)
*   [android/app/src/main/AndroidManifest.xml](file:///Users/smasim/Antigrav/sentinel/android/app/src/main/AndroidManifest.xml)
*   [ios/Runner/AppDelegate.swift](file:///Users/smasim/Antigrav/sentinel/ios/Runner/AppDelegate.swift)

### 2. Firebase Configuration
1.  Create a Firebase project at the [Firebase Console](https://console.firebase.google.com/).
2.  Register Android, iOS, and Web apps inside your project.
3.  Configure the Flutter app using the FlutterFire CLI:
    ```bash
    flutterfire configure
    ```
4.  Alternatively, download the config files and place them in:
    *   `android/app/google-services.json`
    *   `ios/Runner/GoogleService-Info.plist`

## 🛡️ Our Mission

Sentinel was built with the belief that safety should be accessible, discreet, and reliable. Whether walking alone at night or navigating a difficult situation, Sentinel ensures that you are never truly alone.

---
© 2026 Sentinel Safety Team
