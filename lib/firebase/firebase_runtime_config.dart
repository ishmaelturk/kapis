import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

final class FirebaseRuntimeConfig {
  const FirebaseRuntimeConfig({
    required this.apiKey,
    required this.androidAppId,
    required this.macOSAppId,
    required this.webAppId,
    required this.webAppCheckSiteKey,
    required this.messagingSenderId,
    required this.projectId,
    required this.storageBucket,
  });

  factory FirebaseRuntimeConfig.fromEnvironment() {
    return const FirebaseRuntimeConfig(
      apiKey: String.fromEnvironment('KAPIS_FIREBASE_API_KEY'),
      androidAppId: String.fromEnvironment('KAPIS_FIREBASE_ANDROID_APP_ID'),
      macOSAppId: String.fromEnvironment('KAPIS_FIREBASE_MACOS_APP_ID'),
      webAppId: String.fromEnvironment('KAPIS_FIREBASE_WEB_APP_ID'),
      webAppCheckSiteKey: String.fromEnvironment(
        'KAPIS_FIREBASE_WEB_APPCHECK_SITE_KEY',
      ),
      messagingSenderId: String.fromEnvironment(
        'KAPIS_FIREBASE_MESSAGING_SENDER_ID',
      ),
      projectId: String.fromEnvironment('KAPIS_FIREBASE_PROJECT_ID'),
      storageBucket: String.fromEnvironment('KAPIS_FIREBASE_STORAGE_BUCKET'),
    );
  }

  final String apiKey;
  final String androidAppId;
  final String macOSAppId;
  final String webAppId;
  final String webAppCheckSiteKey;
  final String messagingSenderId;
  final String projectId;
  final String storageBucket;

  FirebaseOptions toFirebaseOptions({
    required TargetPlatform platform,
    bool isWeb = kIsWeb,
  }) {
    final (appId, appIdDefine) = isWeb
        ? (webAppId, 'KAPIS_FIREBASE_WEB_APP_ID')
        : switch (platform) {
            TargetPlatform.android => (
              androidAppId,
              'KAPIS_FIREBASE_ANDROID_APP_ID',
            ),
            TargetPlatform.macOS => (macOSAppId, 'KAPIS_FIREBASE_MACOS_APP_ID'),
            _ => throw UnsupportedError(
              'Firebase is configured only for web, Android, and macOS.',
            ),
          };
    final missingFields = <String>[
      if (apiKey.trim().isEmpty) 'KAPIS_FIREBASE_API_KEY',
      if (appId.trim().isEmpty) appIdDefine,
      if (messagingSenderId.trim().isEmpty)
        'KAPIS_FIREBASE_MESSAGING_SENDER_ID',
      if (projectId.trim().isEmpty) 'KAPIS_FIREBASE_PROJECT_ID',
      if (storageBucket.trim().isEmpty) 'KAPIS_FIREBASE_STORAGE_BUCKET',
      if (isWeb && webAppCheckSiteKey.trim().isEmpty)
        'KAPIS_FIREBASE_WEB_APPCHECK_SITE_KEY',
    ];
    if (missingFields.isNotEmpty) {
      throw FirebaseConfigurationException(missingFields);
    }

    return FirebaseOptions(
      apiKey: apiKey.trim(),
      appId: appId.trim(),
      messagingSenderId: messagingSenderId.trim(),
      projectId: projectId.trim(),
      storageBucket: storageBucket.trim(),
      authDomain: isWeb ? '${projectId.trim()}.firebaseapp.com' : null,
    );
  }
}

final class FirebaseConfigurationException implements Exception {
  FirebaseConfigurationException(List<String> missingFields)
    : missingFields = List.unmodifiable(missingFields);

  final List<String> missingFields;

  @override
  String toString() {
    return 'Firebase is not configured. Provide: '
        '${missingFields.join(', ')}.';
  }
}
