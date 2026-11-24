# Kapış

Kapış is a pick-up-only (Gel-Al) donation app for usable second-hand items and
furniture. It is open to people across cities and neighborhoods; student
verification is optional.

## Project status

The app now includes email/password accounts, free pickup-only listings,
neighborhood discovery, approximate OpenStreetMap pins, reservation, and QR
handover. Student verification is optional and uses Firebase email verification
plus the configured domain suffix list. Firebase AI can suggest listing text
from the entered title/description and an optional selected photo, and rank up
to 15 available listings against a receiver's short needs description.

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
To use AI suggestions and ranking, enable Firebase AI Logic and the Gemini
Developer API for the Firebase project. The default model is
`gemini-2.5-flash`; optionally select another supported model with the
`KAPIS_FIREBASE_AI_MODEL` Dart define. AI requests have a 20-second timeout and
fall back to deterministic local suggestions/ranking on service, quota,
configuration, timeout, or invalid-response errors. AI output is advisory and
should be reviewed before publishing or reserving.
The selected photo and listing text are sent to Firebase AI only when requesting
a suggestion. Receiver ranking sends the entered needs description and public
listing title, description, category, condition, and tags for at most 15
listings; it does not send pickup coordinates, neighborhood, or donor IDs.
Public listing documents omit exact pickup coordinates, which are kept in a
Firestore subdocument protected by `firestore.rules`. Public map coordinates
are rounded to two decimal places. The 100 m geofence uses device location and
reported accuracy as a client-side gate; it is not tamper-proof server
attestation. The QR token and Firestore rules authorize the handover.

The app uses OpenStreetMap's public tile endpoint for the current map
implementation. Follow its tile usage policy; use an appropriate tile provider
or self-hosted tiles if production traffic exceeds that service's limits.

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
