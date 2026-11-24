import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
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
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/handover_repository.dart';
import '../domain/repositories/listing_image_storage.dart';
import '../domain/repositories/listing_matchmaker.dart';
import '../domain/repositories/listing_repository.dart';
import '../domain/services/student_email_domain_validator.dart';
import 'firebase_runtime_config.dart';

final firebaseRuntimeConfigProvider = Provider<FirebaseRuntimeConfig>(
  (ref) => FirebaseRuntimeConfig.fromEnvironment(),
);

final firebaseAppProvider = FutureProvider<FirebaseApp>((ref) {
  final options = ref
      .watch(firebaseRuntimeConfigProvider)
      .toFirebaseOptions(platform: defaultTargetPlatform);
  return Firebase.initializeApp(options: options);
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

final listingRepositoryProvider = FutureProvider<ListingRepository>((
  ref,
) async {
  final firestoreFuture = ref.watch(firestoreProvider.future);
  final authFuture = ref.watch(firebaseAuthProvider.future);
  final firestore = await firestoreFuture;
  final auth = await authFuture;
  return FirebaseListingRepository(firestore, auth);
});

final handoverRepositoryProvider = FutureProvider<HandoverRepository>((
  ref,
) async {
  final firestoreFuture = ref.watch(firestoreProvider.future);
  final authFuture = ref.watch(firebaseAuthProvider.future);
  final firestore = await firestoreFuture;
  final auth = await authFuture;
  return FirebaseHandoverRepository(firestore, auth);
});

final listingImageStorageProvider = FutureProvider<ListingImageStorage>((
  ref,
) async {
  final storage = await ref.watch(firebaseStorageProvider.future);
  return FirebaseListingImageStorage(storage);
});

final listingMatchmakerProvider = Provider<ListingMatchmaker>((ref) {
  return FirebaseListingMatchmaker((content) async {
    final app = await ref.read(firebaseAppProvider.future);
    final model = FirebaseAI.googleAI(app: app).generativeModel(
      model: const String.fromEnvironment(
        'KAPIS_FIREBASE_AI_MODEL',
        defaultValue: 'gemini-2.5-flash',
      ),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
        maxOutputTokens: 1400,
      ),
    );
    final response = await model.generateContent([content]);
    return response.text ??
        (throw const FormatException('AI returned an empty response.'));
  });
});
