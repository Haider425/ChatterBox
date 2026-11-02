# ChatterBox

<div align="center">
  <img src="assets/chatterbox-logo.png" alt="ChatterBox Logo" width="120"/>
  
  A modern, feature-rich messaging application built with Flutter and Firebase
</div>

## 🌟 Overview

ChatterBox is a modern messaging application designed to provide a seamless and user-friendly experience for connecting with friends and sharing information. Built using Flutter for cross-platform compatibility, Firebase for backend services, and local storage for data persistence, ChatterBox offers a robust set of features for modern communication needs.

## ✨ Key Features

### Authentication & Security
- 🔐 Secure Firebase Authentication system
- 🔑 Email and password-based login
- 🔄 Password reset functionality
- 👤 User profile management

### Messaging Capabilities
- 💬 Real-time text messaging
- 📎 File sharing (PDFs, Word documents, etc.)
- 📸 In-app camera integration
- 📍 Live location sharing via Google Maps
- ⚡ Push notifications via Firebase Cloud Messaging (FCM)

### User Experience
- 🔍 Friend search functionality
- 💾 Draft message auto-save
- 📱 Intuitive multi-screen navigation
- 🗑️ Chat archive and deletion options
- 💫 Smooth animations and transitions
- 📢 Contextual feedback via Snackbars

## 🛠️ Technical Stack

- **Frontend**: Flutter
- **Backend**: Firebase
- **Authentication**: Firebase Auth
- **Database**: Cloud Firestore
- **Storage**: Firebase Cloud Storage
- **Notifications**: Firebase Cloud Messaging
- **Location Services**: Google Maps API

## 📋 Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Firebase account
- Android Studio / VS Code
- iOS development setup (for iOS builds)

## 🚀 Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/Haider425/ChatterBox.git
   cd ChatterBox
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a new Firebase project
   - Add your Android & iOS apps in Firebase console
   - Download and add configuration files:
     - `google-services.json` for Android
     - `GoogleService-Info.plist` for iOS

4. **Run the app**
   ```bash
   flutter run
   ```

## 📝 Environment Setup

Create a `.env` file in the project root with the following variables:
```
GOOGLE_MAPS_API_KEY=your_api_key_here
FIREBASE_API_KEY=your_firebase_api_key
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  Made by Haider Saleem👋🏽
</div>

## Web build

ChatterBox also runs in the browser at https://haider425.github.io/ChatterBox/.
The `Deploy web build` workflow builds it with Flutter and publishes it to
GitHub Pages on every push to `main`.

One-time setup:

1. Firebase console, Project settings: add a **Web app** and copy its config.
2. GitHub repo, Settings, Secrets and variables, Actions: add these secrets
   from that config: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`,
   `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`,
   `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`.
3. Firebase console, Authentication, Settings, Authorized domains: add
   `haider425.github.io`.
4. GitHub repo, Settings, Pages: set Source to **GitHub Actions**.

Push notifications are mobile only; the web build skips them.
