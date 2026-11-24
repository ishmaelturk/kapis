# Kapış

Kapış is a pick-up-only (Gel-Al) donation app for usable second-hand items and
furniture. It is open to people across cities and neighborhoods; student
verification is optional.
Supported Flutter targets are Android, macOS, and web. Web builds use the
Firebase web app ID and reCAPTCHA App Check site key configured locally.

## Project status

The app now includes email/password accounts, free pickup-only listings,
neighborhood discovery, approximate OpenStreetMap pins, reservation, and QR
handover, plus a receiver's "Ayırttıklarım" list for returning to an active
reservation. Donors can edit or withdraw available listings and optionally add
one public listing photo. Student
verification is optional and uses Firebase email verification
plus the configured domain suffix list. Firebase AI can suggest listing text
from the entered title/description and an optional selected photo, and rank up
to 15 available listings against a receiver's short needs description.
Student email verification is a client-side convenience badge and is visible
only in that account's own settings; it is not shown on listings or verified by
Firestore rules.
Accounts can request password-reset emails, and account creation requires an
eight-character password. In-app account deletion first withdraws the user's
available listings and releases reservations; Firebase may require a recent
sign-in before deleting the account.

The app uses Riverpod for state management. Firebase credentials and generated
platform configuration are local-only; never commit `.env` files,
`lib/firebase_options.dart`, `android/app/google-services.json`, or
`macos/Runner/GoogleService-Info.plist`.

The app initializes a versioned SQLite database (`kapis.db`) at startup. The
initial schema contains a public listing cache table and indexes; exact pickup
coordinates are intentionally excluded. Native builds bundle SQLite through
`sqlite3` build hooks; web uses SQLite compiled to WebAssembly and persists it
in IndexedDB. Users do not need to install SQLite separately. The web build
requires the generated `web/sqlite3.wasm` and `web/sqflite_sw.js` assets; after
updating the web SQLite package, regenerate them with
`dart run sqflite_common_ffi_web:setup`. App display preferences remain in
`SharedPreferences`.

Firebase initialization is lazy and uses `--dart-define-from-file` rather than
the generated platform files. Create an ignored `firebase.local.json` with
`KAPIS_FIREBASE_API_KEY`, `KAPIS_FIREBASE_ANDROID_APP_ID`,
`KAPIS_FIREBASE_MACOS_APP_ID`, `KAPIS_FIREBASE_WEB_APP_ID`,
`KAPIS_FIREBASE_WEB_APPCHECK_SITE_KEY`, `KAPIS_FIREBASE_MESSAGING_SENDER_ID`,
`KAPIS_FIREBASE_PROJECT_ID`, and `KAPIS_FIREBASE_STORAGE_BUCKET`. Optionally
set `KAPIS_STUDENT_EMAIL_DOMAINS` to a comma-separated list of approved
institution domains. Student verification uses Firebase Auth email verification
and local suffix checks only; no external student-verification provider/API is
called.
Enable Email/Password sign-in in the Firebase Authentication console before
using account operations.
Firebase App Check is activated after Firebase initialization: Android release
builds use Play Integrity, macOS release builds use DeviceCheck, and debug
builds use the debug provider. Web uses reCAPTCHA v3 with the configured site
key. Register each platform app in the Firebase App Check console before
rollout, and add local web origins to Firebase Authentication's authorized
domains. For local debug runs, copy the debug token
shown in the app logs into the registered app's App Check debug-token list;
never commit or share that token. Validate the app with enforcement disabled
first, then enable App Check enforcement for Firestore, Storage, and Firebase
AI Logic in the Firebase console. Enforcement is a project-console setting and
has not been enabled by this repository.
To use AI suggestions and ranking, enable Firebase AI Logic and the Gemini
Developer API for the Firebase project. The default model is
`gemini-3.8-flash`; optionally select another supported model with the
`KAPIS_FIREBASE_AI_MODEL` Dart define. AI requests have a 20-second timeout and
fall back to deterministic local suggestions/ranking on service, quota,
configuration, timeout, or invalid-response errors. AI output is advisory and
should be reviewed before publishing or reserving.
Selected photos are re-encoded as JPEG before upload, stripping EXIF metadata
including GPS data. Listing photos are public and stored under
`listing-images/{listingId}/primary`; Storage rules allow only the listing owner
to upload or replace them. The selected photo and listing text are sent to
Firebase AI only when requesting a suggestion. Receiver ranking sends the entered needs description and public
listing title, description, category, condition, and tags for at most 15
listings; it does not send pickup coordinates, neighborhood, or donor IDs.
Public listing documents omit exact pickup coordinates, which are kept in a
Firestore subdocument protected by `firestore.rules`. Public map coordinates
are rounded to two decimal places. The 100 m geofence uses device location and
reported accuracy as a client-side gate; it is not tamper-proof server
attestation. The QR token and Firestore rules authorize the handover.
Discovery requires sign-in. Listing documents retain the donor UID for
ownership checks, but Firestore rules prevent unauthenticated clients from
reading listings. Signed-in users can report an item; reports are create-only
and unreadable by app clients. A reported item is hidden from the reporter for
the current discovery session; global moderation tooling is not included.
Firestore rules reject whitespace-only listing text and tags that are blank,
non-string, or longer than 32 characters. The client trims submitted tags and
skips/logs malformed legacy listing documents individually so they cannot take
down the entire discovery feed.
Neighborhood filtering stores a normalized `pickupAreaKey` (Turkish I/İ and
common Turkish diacritics folded) alongside the display name for stable
case-insensitive matching. Legacy listings without that field remain readable
and withdrawable; editing one adds the normalized key so it becomes filterable.
Reservations expire after 48 hours and each account can hold at most three at
once. Receivers can cancel before handover confirmation; donors can release the
reservation or withdraw the listing. Expired reservations are released
opportunistically when another receiver tries to reserve the listing; there is
no scheduled backend cleanup. An expired listing remains out of discovery
until its donor releases it or a receiver with its listing ID triggers release
while reserving. To permit that cleanup, signed-in clients can read the
unconfirmed reservation metadata after expiry; exact pickup access still ends
at expiry and remains restricted to the donor and active receiver.
Reservation-slot documents and the reservation/listing updates are written
atomically and enforced by the Firestore rules.

The app uses OpenStreetMap's public tile endpoint for the current map
implementation. Follow its tile usage policy; use an appropriate tile provider
or self-hosted tiles if production traffic exceeds that service's limits.
Configure another compatible tile URL with the
`KAPIS_MAP_TILE_URL` Dart define, for example
`https://tiles.example.com/{z}/{x}/{y}.png`; the default remains the OSM
standard tile endpoint. Keep required attribution visible and follow the
selected provider's usage policy.

The app's Turkish “Gizlilik ve kullanım koşulları” screen is linked from
Settings and account creation. It summarizes Firebase data handling, exact
pickup-location access, optional Google AI processing, and account deletion.
It is general product information, not legal advice; before public release,
have it reviewed for KVKK and applicable consumer-law requirements and add the
data-controller contact and any required retention/rights details.

Android release builds require a private signing key configured in the ignored
`android/key.properties` file. Set `keyAlias`, `keyPassword`, `storeFile`, and
`storePassword`; store the keystore at a protected location and use its path
for `storeFile`. Release tasks intentionally fail if any signing values are
missing; debug builds do not need this file. The Android application ID is
`com.kapis.app.kapis` and must match the registered Firebase Android app; treat
it as immutable after publishing.

Before using Firebase services, deploy the repository's rules and indexes with
`firebase deploy --only firestore:rules,firestore:indexes,storage --project <project-id>`.

## Development

Requires Dart 3.13+ and Flutter 3.47+.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d macos --dart-define-from-file=firebase.local.json
flutter run -d chrome --dart-define-from-file=firebase.local.json
```

For Android, connect the target device and run `flutter devices`, then
`flutter run -d <device-id> --dart-define-from-file=firebase.local.json`.

### Firebase security rules tests

The Firestore and Storage rules tests use the local Firebase Emulator Suite.
Install Node.js 20+ and Java 21+, then run:

```sh
cd rules-test
npm install
npm run test:emulators
```

The script starts only the Firestore and Storage emulators with a demo project;
it does not contact a live Firebase project. Emulator ports are 8080 and 9199.
