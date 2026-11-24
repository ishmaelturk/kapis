import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/firebase_auth_repository.dart';
import '../data/firebase/firebase_handover_repository.dart';
import '../data/firebase/firebase_listing_image_storage.dart';
import '../data/firebase/firebase_listing_matchmaker.dart';
import '../data/firebase/firebase_listing_repository.dart';
import '../data/firebase/firebase_listing_report_repository.dart';
import '../domain/models/listing.dart';
import '../domain/models/user_account.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/handover_repository.dart';
import '../domain/repositories/listing_image_storage.dart';
import '../domain/repositories/listing_matchmaker.dart';
import '../domain/repositories/listing_repository.dart';
import '../domain/repositories/listing_report_repository.dart';
import '../domain/services/student_email_domain_validator.dart';
import 'firebase_runtime_config.dart';

final firebaseRuntimeConfigProvider = Provider<FirebaseRuntimeConfig>(
  (ref) => FirebaseRuntimeConfig.fromEnvironment(),
);

final firebaseAppProvider = FutureProvider<FirebaseApp>((ref) {
  final config = ref.watch(firebaseRuntimeConfigProvider);
  final options = config.toFirebaseOptions(platform: defaultTargetPlatform);
  return Firebase.initializeApp(options: options).then((app) async {
    final appCheck = FirebaseAppCheck.instanceFor(app: app);
    if (kIsWeb) {
      await appCheck.activate(
        providerWeb: ReCaptchaV3Provider(config.webAppCheckSiteKey.trim()),
      );
    } else {
      await appCheck.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    }
    return app;
  });
});

final firebaseAppCheckProvider = FutureProvider<FirebaseAppCheck>((ref) async {
  final app = await ref.watch(firebaseAppProvider.future);
  return FirebaseAppCheck.instanceFor(app: app);
});

final firebaseAuthProvider = FutureProvider<FirebaseAuth>((ref) async {
  final app = await ref.watch(firebaseAppProvider.future);
  return FirebaseAuth.instanceFor(app: app);
});

final firestoreProvider = FutureProvider<FirebaseFirestore>((ref) async {
  final app = await ref.watch(firebaseAppProvider.future);
  return FirebaseFirestore.instanceFor(app: app);
});

final firebaseStorageProvider = FutureProvider<FirebaseStorage>((ref) async {
  final app = await ref.watch(firebaseAppProvider.future);
  return FirebaseStorage.instanceFor(app: app);
});

final studentEmailDomainValidatorProvider =
    Provider<StudentEmailDomainValidator>((ref) {
      const configuredDomains = String.fromEnvironment(
        'KAPIS_STUDENT_EMAIL_DOMAINS',
      );
      return StudentEmailDomainValidator(
        approvedDomains: configuredDomains
            .split(',')
            .where((domain) => domain.trim().isNotEmpty),
      );
    });

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final authFuture = ref.watch(firebaseAuthProvider.future);
  final domainValidator = ref.watch(studentEmailDomainValidatorProvider);
  final auth = await authFuture;
  return FirebaseAuthRepository(auth, domainValidator);
});

final authStateProvider = StreamProvider<UserAccount?>((ref) async* {
  final repository = await ref.watch(authRepositoryProvider.future);
  yield* repository.watchUser();
});

final listingRepositoryProvider = FutureProvider<ListingRepository>((
  ref,
) async {
  final firestoreFuture = ref.watch(firestoreProvider.future);
  final authFuture = ref.watch(firebaseAuthProvider.future);
  final firestore = await firestoreFuture;
  final auth = await authFuture;
  return FirebaseListingRepository(firestore, auth);
});

final listingReportRepositoryProvider = FutureProvider<ListingReportRepository>(
  (ref) async {
    final firestore = await ref.watch(firestoreProvider.future);
    final auth = await ref.watch(firebaseAuthProvider.future);
    return FirebaseListingReportRepository(firestore, auth);
  },
);

final handoverRepositoryProvider = FutureProvider<HandoverRepository>((
  ref,
) async {
  final firestoreFuture = ref.watch(firestoreProvider.future);
  final authFuture = ref.watch(firebaseAuthProvider.future);
  final firestore = await firestoreFuture;
  final auth = await authFuture;
  return FirebaseHandoverRepository(firestore, auth);
});

final handoverListingStatusProvider = StreamProvider.autoDispose
    .family<ListingStatus?, String>((ref, listingId) async* {
      final repository = await ref.watch(handoverRepositoryProvider.future);
      yield* repository.watchListingStatus(listingId);
    });

final listingImageStorageProvider = FutureProvider<ListingImageStorage>((
  ref,
) async {
  final storage = await ref.watch(firebaseStorageProvider.future);
  return FirebaseListingImageStorage(storage);
});

final listingImageUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, path) async {
      final storage = await ref.watch(listingImageStorageProvider.future);
      return storage.getDownloadUrl(path);
    });

final firebaseGenerativeModelProvider = FutureProvider<GenerativeModel>((
  ref,
) async {
  final app = await ref.watch(firebaseAppProvider.future);
  return FirebaseAI.googleAI(app: app).generativeModel(
    model: const String.fromEnvironment(
      'KAPIS_FIREBASE_AI_MODEL',
      defaultValue: 'gemini-3.8-flash',
    ),
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      temperature: 0.2,
      maxOutputTokens: 1400,
    ),
  );
});

final listingMatchmakerProvider = Provider<ListingMatchmaker>((ref) {
  return FirebaseListingMatchmaker((content) async {
    final model = await ref.read(firebaseGenerativeModelProvider.future);
    final response = await model.generateContent([content]);
    return response.text ??
        (throw const FormatException('AI returned an empty response.'));
  });
});
