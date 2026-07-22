import 'dart:convert' show jsonDecode;

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

  /// Parse JS `getValidate()` payload from the embedded GeeTest fullpage widget.
  ///
  /// Accepts [Map], nested maps from InAppWebView, or a JSON [String] — matching
  /// PiliPlus's loose `res is Map` handling.
  static GeetestResult? tryParse(Object? raw) {
    final map = _asStringKeyedMap(raw);
    if (map == null) return null;

    final challenge = _readString(map, const [
      'geetest_challenge',
      'challenge',
    ]);
    final validate = _readString(map, const [
      'geetest_validate',
      'validate',
    ]);
    var seccode = _readString(map, const [
      'geetest_seccode',
      'seccode',
    ]);

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

  static Map<String, dynamic>? _asStringKeyedMap(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      try {
        return _asStringKeyedMap(jsonDecode(s));
      } on Object {
        return null;
      }
    }
    if (raw is Map) {
      final out = <String, dynamic>{};
      raw.forEach((key, value) {
        if (key != null) {
          out[key.toString()] = value;
        }
      });
      // Some bridges wrap the real payload under `result`.
      final nested = out['result'];
      if (nested is Map &&
          !out.containsKey('geetest_validate') &&
          !out.containsKey('geetest_challenge')) {
        return _asStringKeyedMap(nested);
      }
      return out;
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = map[key];
      if (v == null) continue;
      final s = v.toString();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return null;
  }
}
