import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/firebase/firebase_runtime_config.dart';

void main() {
  test(
    'selects the registered Firebase app id for each supported platform',
    () {
      const config = FirebaseRuntimeConfig(
        apiKey: 'public-key',
        androidAppId: 'android-app',
        macOSAppId: 'macos-app',
        webAppId: 'web-app',
        webAppCheckSiteKey: 'captcha-site-key',
        messagingSenderId: 'sender',
        projectId: 'project',
        storageBucket: 'project.appspot.com',
      );

      expect(
        config.toFirebaseOptions(platform: TargetPlatform.android).appId,
        'android-app',
      );
      expect(
        config.toFirebaseOptions(platform: TargetPlatform.macOS).appId,
        'macos-app',
      );
      final webOptions = config.toFirebaseOptions(
        platform: TargetPlatform.macOS,
        isWeb: true,
      );
      expect(webOptions.appId, 'web-app');
      expect(webOptions.authDomain, 'project.firebaseapp.com');
    },
  );

  test('reports missing values without echoing configured credentials', () {
    const config = FirebaseRuntimeConfig(
      apiKey: '',
      androidAppId: '',
      macOSAppId: '',
      webAppId: '',
      webAppCheckSiteKey: '',
      messagingSenderId: '',
      projectId: '',
      storageBucket: '',
    );

    expect(
      () => config.toFirebaseOptions(platform: TargetPlatform.android),
      throwsA(isA<FirebaseConfigurationException>()),
    );
  });

  test('requires a separate web app id when building for web', () {
    const config = FirebaseRuntimeConfig(
      apiKey: 'public-key',
      androidAppId: 'android-app',
      macOSAppId: 'macos-app',
      webAppId: '',
      webAppCheckSiteKey: 'captcha-site-key',
      messagingSenderId: 'sender',
      projectId: 'project',
      storageBucket: 'project.appspot.com',
    );

    expect(
      () =>
          config.toFirebaseOptions(platform: TargetPlatform.macOS, isWeb: true),
      throwsA(isA<FirebaseConfigurationException>()),
    );
  });

  test('requires a web App Check key when building for web', () {
    const config = FirebaseRuntimeConfig(
      apiKey: 'public-key',
      androidAppId: 'android-app',
      macOSAppId: 'macos-app',
      webAppId: 'web-app',
      webAppCheckSiteKey: '',
      messagingSenderId: 'sender',
      projectId: 'project',
      storageBucket: 'project.appspot.com',
    );

    expect(
      () =>
          config.toFirebaseOptions(platform: TargetPlatform.macOS, isWeb: true),
      throwsA(isA<FirebaseConfigurationException>()),
    );
  });
}
