# Kapış

Kapış is a pick-up-only (Gel-Al) donation app for usable second-hand items and
furniture. It is open to people across cities and neighborhoods; student
verification is optional.

## Project status

The repository currently contains the Flutter app shell. Planned capabilities
include listing and discovery, direct pickup, optional student verification,
OpenStreetMap, location-based handover checks, QR handover, and Firebase-backed
services. Do not treat planned capabilities as implemented until they are
available in the app.

The app uses Riverpod for state management. Firebase credentials and generated
platform configuration are local-only; never commit `.env` files,
`lib/firebase_options.dart`, `android/app/google-services.json`, or
`macos/Runner/GoogleService-Info.plist`.

Firebase initialization is lazy and uses `--dart-define-from-file` rather than
the generated platform files. Create an ignored `firebase.local.json` with
`KAPIS_FIREBASE_API_KEY`, `KAPIS_FIREBASE_ANDROID_APP_ID`,
`KAPIS_FIREBASE_MACOS_APP_ID`, `KAPIS_FIREBASE_MESSAGING_SENDER_ID`,
`KAPIS_FIREBASE_PROJECT_ID`, and `KAPIS_FIREBASE_STORAGE_BUCKET`. Optionally
set `KAPIS_STUDENT_EMAIL_DOMAINS` to a comma-separated list of approved
institution domains. Student verification uses Firebase Auth email verification
and local suffix checks only; no external student-verification provider/API is
called.
Enable Email/Password sign-in in the Firebase Authentication console before
using account operations.
Public listing documents omit exact pickup coordinates, which are kept in a
Firestore subdocument protected by `firestore.rules`.

Before using Firebase services, deploy the repository's rules and indexes with
`firebase deploy --only firestore:rules,firestore:indexes,storage --project <project-id>`.

## Development

Requires Dart 3.13+ and Flutter 3.47+.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d macos --dart-define-from-file=firebase.local.json
```

For Android, connect the target device and run `flutter devices`, then
`flutter run -d <device-id> --dart-define-from-file=firebase.local.json`.
