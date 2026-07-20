/// GeeTest client validation payload (PiliPlus-compatible field names).
class GeetestResult {
  const GeetestResult({
    required this.challenge,
    required this.validate,
    required this.seccode,
  });

  final String challenge;
  final String validate;
  final String seccode;

  /// Parse JS `getValidate()` map from the embedded GeeTest fullpage widget.
  static GeetestResult? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final challenge = raw['geetest_challenge']?.toString();
    final validate = raw['geetest_validate']?.toString();
    var seccode = raw['geetest_seccode']?.toString();
    if (challenge == null ||
        challenge.isEmpty ||
        validate == null ||
        validate.isEmpty) {
      return null;
    }
    if (seccode == null || seccode.isEmpty) {
      seccode = '$validate|jordan';
    }
    return GeetestResult(
      challenge: challenge,
      validate: validate,
      seccode: seccode,
    );
  }
}
