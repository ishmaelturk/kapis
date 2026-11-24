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

## Development

Requires Dart 3.13+ and Flutter 3.47+.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

For Android, connect the target device and run `flutter devices`, then
`flutter run -d <device-id>`.
