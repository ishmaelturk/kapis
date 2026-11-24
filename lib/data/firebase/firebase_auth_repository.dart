import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/user_account.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/student_email_domain_validator.dart';

final class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository(this._auth, this._studentEmailDomainValidator);

  final FirebaseAuth _auth;
  final StudentEmailDomainValidator _studentEmailDomainValidator;

  @override
  Stream<UserAccount?> watchUser() {
    return _auth.userChanges().map(_toAccount);
  }

  @override
  Future<UserAccount> createAccount({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _requireAccount(credential.user);
  }

  @override
  Future<UserAccount> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _requireAccount(credential.user);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> requestStudentEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthenticationRequiredException();
    }
    if (!_studentEmailDomainValidator.isEligible(user.email ?? '')) {
      throw const StudentEmailNotEligibleException();
    }
    await user.sendEmailVerification();
  }

  @override
  Future<bool> refreshStudentVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    await user.reload();
    final refreshedUser = _auth.currentUser;
    final email = refreshedUser?.email;
    return refreshedUser != null &&
        refreshedUser.emailVerified &&
        email != null &&
        _studentEmailDomainValidator.isEligible(email);
  }

  UserAccount _requireAccount(User? user) {
    return _toAccount(user) ??
        (throw StateError('Firebase Auth returned no user.'));
  }

  UserAccount? _toAccount(User? user) {
    if (user == null) {
      return null;
    }
    return UserAccount(
      id: user.uid,
      email: user.email,
      emailVerified: user.emailVerified,
    );
  }
}
