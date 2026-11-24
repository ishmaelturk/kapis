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
    },
  );

  test('reports missing values without echoing configured credentials', () {
    const config = FirebaseRuntimeConfig(
      apiKey: '',
      androidAppId: '',
      macOSAppId: '',
      messagingSenderId: '',
      projectId: '',
      storageBucket: '',
    );

    expect(
      () => config.toFirebaseOptions(platform: TargetPlatform.android),
      throwsA(isA<FirebaseConfigurationException>()),
    );
  });
}
