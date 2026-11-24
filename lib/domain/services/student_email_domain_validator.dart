final class StudentEmailDomainValidator {
  StudentEmailDomainValidator({required Iterable<String> approvedDomains})
    : approvedDomains = Set.unmodifiable(
        approvedDomains.map(_normalizeApprovedDomain),
      );

  static final _domainPattern = RegExp(
    r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+'
    r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
  );

  final Set<String> approvedDomains;

  bool isEligible(String email) {
    if (email.trim() != email) {
      return false;
    }
    final separator = email.indexOf('@');
    if (separator <= 0 ||
        separator != email.lastIndexOf('@') ||
        separator == email.length - 1 ||
        email.substring(0, separator).contains(RegExp(r'\s'))) {
      return false;
    }

    final domain = email.substring(separator + 1).toLowerCase();
    if (!_domainPattern.hasMatch(domain)) {
      return false;
    }
    return approvedDomains.any(
      (approved) => domain == approved || domain.endsWith('.$approved'),
    );
  }

  static String _normalizeApprovedDomain(String domain) {
    final normalized = domain.trim().toLowerCase();
    if (!_domainPattern.hasMatch(normalized)) {
      throw ArgumentError.value(
        domain,
        'approvedDomains',
        'Each value must be a valid domain suffix.',
      );
    }
    return normalized;
  }
}
