# Medicine Reminder App

A Flutter-based medication reminder application developed as a final-year university project. The app helps users manage their daily medication through scheduled notifications, caretaker alerts, medical condition information, and an AI-powered health assistant.

## Features

- **Medication reminders** — Schedule daily, weekly, or one-time reminders. Notifications fire even when the app is fully closed.
- **Alarm screen** — A full-screen alarm appears when a reminder fires, with options to confirm ("I've taken it") or snooze.
- **Caretaker alerts** — If an alarm is not dismissed within 5 minutes, an SMS is automatically sent to a nominated caretaker.
- **Medical information** — Evidence-based information on common conditions (asthma, diabetes, high blood pressure, etc.) with dosage timing advice backed by peer-reviewed references.
- **AI health assistant** — Powered by Google Gemini 2.5 Flash via Firebase AI. The assistant is aware of the user's current reminders and city, and can answer questions about medications and suggest nearby pharmacies.
- **Accessibility** — Adjustable text size, large button mode, and high contrast mode.
- **Dark mode** — Full dark theme support.
- **User accounts** — Sign in with email/password or Google. Data syncs across devices via Firebase Firestore.

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Backend / Auth | Firebase (Firestore, Firebase Auth) |
| Notifications | flutter_local_notifications + Android AlarmManager |
| AI | Google Gemini 2.5 Flash (via firebase_ai) |
| SMS | Android SmsManager (native MethodChannel) |

## Getting Started

### Prerequisites

- Flutter SDK
- Android Studio or VS Code with Flutter extension
- A Firebase project with Firestore, Authentication, and Firebase AI enabled

### Run in debug mode

```bash
flutter pub get
flutter run
```

### Build a release APK

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## Project Structure

```
lib/
├── main.dart                # App entry point, theme setup
├── auth_gate.dart           # Routes between login and home based on auth state
├── login_page.dart          # Email/password and Google sign-in
├── homepage.dart            # Reminder list and add/edit reminder flow
├── notification_service.dart# Schedules and cancels local notifications
├── alarm_service.dart       # Handles full-screen alarm when reminder fires
├── alarm_screen.dart        # UI shown when alarm fires
├── medical.dart             # Medical conditions information page
├── ai_chat.dart             # AI assistant chat UI
├── ai_service.dart          # Gemini API integration and chat history
├── settings.dart            # Settings page
└── app_settings.dart        # Persistent user preferences (Firestore-backed)
```
