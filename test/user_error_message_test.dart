import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/application/user_error_message.dart';

void main() {
  test('maps common Firebase Auth failures to Turkish messages', () {
    expect(
      userMessageFor(
        FirebaseAuthException(code: 'wrong-password', message: 'raw secret'),
      ),
      'E-posta veya şifre hatalı.',
    );
    expect(
      userMessageFor(FirebaseAuthException(code: 'email-already-in-use')),
      'Bu e-posta adresi zaten kullanılıyor.',
    );
  });

  test('does not expose raw technical exception text', () {
    final message = userMessageFor(StateError('internal stack detail'));

    expect(message, contains('tekrar dene'));
    expect(message, isNot(contains('internal stack detail')));
  });
}
