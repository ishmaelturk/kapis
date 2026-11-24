import '../models/user_account.dart';

abstract interface class AuthRepository {
  Stream<UserAccount?> watchUser();

  Future<UserAccount> createAccount({
    required String email,
    required String password,
  });

  Future<UserAccount> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> requestStudentEmailVerification();

  Future<bool> refreshStudentVerification();
}

final class AuthenticationRequiredException implements Exception {
  const AuthenticationRequiredException();

  @override
  String toString() => 'Sign in is required for this action.';
}

final class StudentEmailNotEligibleException implements Exception {
  const StudentEmailNotEligibleException();

  @override
  String toString() =>
      'This email domain is not configured for student verification.';
}
