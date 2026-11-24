import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/domain/services/student_email_domain_validator.dart';

void main() {
  test(
    'matches exact domains and their subdomains only at a label boundary',
    () {
      final validator = StudentEmailDomainValidator(
        approvedDomains: const ['uni.example.edu'],
      );

      expect(validator.isEligible('student@uni.example.edu'), isTrue);
      expect(validator.isEligible('student@mail.uni.example.edu'), isTrue);
      expect(validator.isEligible('student@notuni.example.edu'), isFalse);
      expect(
        validator.isEligible('student@uni.example.edu.attacker.test'),
        isFalse,
      );
    },
  );

  test('rejects malformed email addresses and allowlist entries', () {
    final validator = StudentEmailDomainValidator(
      approvedDomains: const ['uni.example.edu'],
    );

    expect(validator.isEligible('student@@uni.example.edu'), isFalse);
    expect(validator.isEligible('student@'), isFalse);
    expect(validator.isEligible('student user@uni.example.edu'), isFalse);
    expect(
      () =>
          StudentEmailDomainValidator(approvedDomains: const ['@example.edu']),
      throwsArgumentError,
    );
  });
}
