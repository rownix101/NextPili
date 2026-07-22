import 'package:flutter_test/flutter_test.dart';
import 'package:nextpili/features/auth/geetest/geetest_result.dart';

void main() {
  group('GeetestResult.tryParse', () {
    test('parses string-keyed map', () {
      final r = GeetestResult.tryParse({
        'geetest_challenge': 'ch',
        'geetest_validate': 'val',
        'geetest_seccode': 'val|jordan',
      });
      expect(r, isNotNull);
      expect(r!.challenge, 'ch');
      expect(r.validate, 'val');
      expect(r.seccode, 'val|jordan');
    });

    test('accepts Object keys and fills seccode', () {
      final r = GeetestResult.tryParse(<Object?, Object?>{
        'geetest_challenge': 'ch2',
        'geetest_validate': 'v2',
      });
      expect(r, isNotNull);
      expect(r!.seccode, 'v2|jordan');
    });

    test('parses JSON string', () {
      final r = GeetestResult.tryParse(
        '{"geetest_challenge":"c","geetest_validate":"v","geetest_seccode":"s"}',
      );
      expect(r?.challenge, 'c');
      expect(r?.validate, 'v');
      expect(r?.seccode, 's');
    });

    test('returns null on incomplete payload', () {
      expect(GeetestResult.tryParse({'geetest_challenge': 'only'}), isNull);
      expect(GeetestResult.tryParse(null), isNull);
      expect(GeetestResult.tryParse(42), isNull);
    });
  });
}
