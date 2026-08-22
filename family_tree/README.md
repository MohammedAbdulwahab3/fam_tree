# Family Tree Frontend

Flutter client for exploring a shared family tree, managing member profiles, and using family-wide social features such as posts, chat, events, and admin tools.

## What This App Includes

- Animated landing and authentication flow
- Interactive tree view with pan, zoom, filtering, and export/print actions
- Dashboard and profile pages with responsive wide-screen layouts
- Group space for feed, chat, events, and member browsing
- Admin dashboard for person, post, event, and user management
- Firebase integration for auth, Firestore, storage, and messaging
- HTTP API integration for backend-managed data and admin actions

## Platform Scope

This repository currently contains Flutter targets for:

- `web`
- `android`
- `ios`

The UI includes wide-screen layouts that work well on desktop browsers, but native desktop runners (`linux`, `macos`, `windows`) are not checked into this project yet.

## App Entry Points And Routes

The app starts in [`lib/main.dart`](lib/main.dart) and registers these main routes:

- `/` -> landing page
- `/login` -> sign in and account access
- `/tree` -> main family tree for `main-family-tree`
- `/tree/:id` -> specific family tree instance
- `/admin` -> admin dashboard
- `/admin/artboard` -> admin family artboard editor
- `/group` -> family feed, chat, events, and members

## Architecture Summary

### UI Areas

- [`lib/features/auth`](lib/features/auth): landing, login, linking profiles
- [`lib/features/tree_view`](lib/features/tree_view): interactive tree visualization
- [`lib/features/dashboard`](lib/features/dashboard): signed-in member dashboard
- [`lib/features/profile`](lib/features/profile): user profile experience
- [`lib/features/group`](lib/features/group): feed, chat, events, members
- [`lib/features/admin`](lib/features/admin): admin-only management flows

### Data Layer

- [`lib/data/services/firebase_service.dart`](lib/data/services/firebase_service.dart): Firebase bootstrapping
- [`lib/data/services/api_service.dart`](lib/data/services/api_service.dart): backend HTTP client
- [`lib/data/repositories`](lib/data/repositories): person, group, and admin repositories
- [`lib/providers`](lib/providers): Riverpod state and role helpers

## Tech Stack

- Flutter
- Riverpod
- Go Router
- Firebase Auth, Firestore, Storage, Messaging
- `http` for backend API access
- `graphview` for tree layout support
- `printing` and `pdf` for export/print flows

## Local Setup

See the focused setup guide in [`SETUP.md`](SETUP.md). Short version:

```bash
cd /home/maw/Desktop/family_tree/family_tree
flutter pub get
flutter run -d chrome
```

## Backend And Firebase Expectations

This frontend depends on two services:

1. Firebase configuration through [`lib/firebase_options.dart`](lib/firebase_options.dart)
2. The Family Tree backend API, currently referenced in [`lib/data/services/api_service.dart`](lib/data/services/api_service.dart) with `baseUrl = 'http://13.48.124.170:5000'`

If you want a fully local environment, update the API base URL and run the backend in [`../backend`](../backend).

## Current Constraints

- Many flows are still hardcoded to the family tree id `main-family-tree`
- The backend URL is committed in the client instead of being environment-driven
- Native desktop runners are not present in the repo
- Several feature gaps are already tracked in [`docs/FRONTEND_FEATURES_GAP.md`](docs/FRONTEND_FEATURES_GAP.md)

## Additional Docs

- [`SETUP.md`](SETUP.md): run and configure the frontend
- [`docs/FRONTEND_FEATURES_GAP.md`](docs/FRONTEND_FEATURES_GAP.md): missing or partial frontend features
- [`docs/PREVIOUS_ANALYSIS_SUMMARY.md`](docs/PREVIOUS_ANALYSIS_SUMMARY.md): prior analysis notes
- [`../backend/README.md`](../backend/README.md): backend API and deployment details
