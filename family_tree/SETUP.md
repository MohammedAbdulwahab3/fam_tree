# Setup Guide

## Prerequisites

- Flutter SDK installed and on `PATH`
- A working Firebase project if you want your own auth/data/storage setup
- Access to the Family Tree backend API if you need full non-demo functionality

## Supported Targets In This Repo

Configured Flutter targets:

- Web
- Android
- iOS

If you need native desktop builds, generate and configure the missing Flutter desktop runners first.

## 1. Install Dependencies

```bash
cd /home/maw/Desktop/family_tree/family_tree
flutter pub get
```

## 2. Configure Firebase

The app initializes Firebase on startup through [`lib/data/services/firebase_service.dart`](lib/data/services/firebase_service.dart).

### Fastest Path

If the checked-in Firebase config matches your environment, you can run the app directly.

```bash
flutter run -d chrome
```

### Custom Firebase Project

1. Create a Firebase project.
2. Install FlutterFire CLI.
3. Re-generate [`lib/firebase_options.dart`](lib/firebase_options.dart).
4. Replace mobile config files as needed:
   - [`android/app/google-services.json`](android/app/google-services.json)
   - iOS `GoogleService-Info.plist` if you add it for iOS
5. Enable these Firebase products:
   - Authentication
   - Firestore Database
   - Storage
   - Cloud Messaging if you plan to use notifications

Commands:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

## 3. Check Backend Connectivity

The client also calls a separate backend API from [`lib/data/services/api_service.dart`](lib/data/services/api_service.dart).

Current code default:

```text
http://13.48.124.170:5000
```

For local development, change that base URL to your local backend and run the server from [`../backend`](../backend).

## 4. Run The App

### Web

```bash
flutter run -d chrome
```

### Android Or iOS

```bash
flutter run
```

## 5. Verify Core Flows

- Open `/` and confirm the landing page loads
- Sign in from `/login`
- Open `/tree` and verify family members render
- Open `/group` and verify feed/chat/events load
- If using an admin account, open `/admin`

## Notes About The Current App State

- The primary tree id used across the app is `main-family-tree`
- Some areas work from Firebase directly while others depend on backend endpoints
- Wide-screen layouts are implemented for browser use, but this is not the same as native desktop support

## Useful References

- [`README.md`](README.md)
- [`docs/FRONTEND_FEATURES_GAP.md`](docs/FRONTEND_FEATURES_GAP.md)
- [`../backend/README.md`](../backend/README.md)
