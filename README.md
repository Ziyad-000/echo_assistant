# 🌊 Echo Assistant

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Gemini](https://img.shields.io/badge/Google%20Gemini-4285F4?style=for-the-badge&logo=google&logoColor=white)
![Clean Architecture](https://img.shields.io/badge/Architecture-Clean-green?style=for-the-badge)

**Echo Assistant** is a local-first, voice-enabled AI companion designed specifically for software engineers. It doesn't just chat; it remembers your stack, your OS, and your technical preferences across every session using its native **Persistent Technical Memory**.

## 🚀 Key Features

*   **🧠 Persistent Technical Memory**: Utilizes a SQLite-backed Entity-Attribute-Value (EAV) model to automatically extract and persist your technical facts.
*   **🎙️ Voice-First Developer UX**: High-fidelity Speech-to-Text pipeline with real-time mathematical amplitude visualization.
*   **✨ Glassmorphism UI**: A stunning, premium interface featuring dynamic pulse animations and sleek state transitions.
*   **🛡️ Privacy-First & Local-First**: Your conversation history and technical facts are stored securely on your local device.
*   **🤖 Expert Data Extraction**: Powered by Gemini 1.5 Flash, specifically tuned to recognize and categorize technical metadata.

## 🛠️ Tech Stack

| Component | Technology |
| :--- | :--- |
| **Framework** | Flutter (Dart) |
| **AI Engine** | Google Gemini 1.5 Flash |
| **State Management** | BLoC / Cubit |
| **Local Database** | SQLite (sqflite) |
| **Navigation** | GoRouter |
| **Dependency Injection** | GetIt |
| **UI Aesthetics** | Vanilla CSS + Material 3 Glassmorphism |

## 🏗️ Architecture

Echo Assistant follows a strict **3-Layer Clean Architecture** pattern to ensure scalability and testability:

1.  **Data Layer**: Handles raw data transitions, SQLite interactions, and Remote API calls via Gemini.
2.  **Domain Layer**: Contains the pure business logic, Entities, and UseCases (e.g., `SaveUserFactUseCase`).
3.  **Presentation Layer**: Manages the UI state through BLoC/Cubit, providing a reactive and detached interface.

## 🏁 Quick Start

### Prerequisites
- Flutter SDK installed.
- A valid Google Gemini API Key.

### Installation
1.  Clone the repository.
2.  Create a `.env` file in the root and add your key: `GEMINI_API_KEY=your_key_here`.
3.  Run `flutter pub get`.
4.  Launch the app: `flutter run`.

### Running Integration Tests
To execute the full-scale 50-scenario Robot-Pattern test suite:
```bash
flutter test integration_test/echo_automation_test.dart
```

## 🛡️ Security & Performance

- **SQL Injection Protection**: All local persistence utilizes parameterized bindings via the SQLite native layer.
- **Fire-and-Forget Persistence**: Technical fact extraction runs on a non-blocking background thread, ensuring zero UI jank during chat interactions.
- **Async Sanitization**: Model responses are sanitized via RegEx pre-rendering to strip technical tags from user visibility.
