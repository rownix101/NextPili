import 'package:flutter_test/flutter_test.dart';
import 'package:nextpili/bridge/fake_core_api.dart';

void main() {
  test('FakeCoreApi exposes P0 surface', () {
    final api = FakeCoreApi();
    expect(api.ping(), 'pong');
    final v = api.apiVersion();
    expect(v.major, 0);
    expect(v.minor, 1);
    expect(v.core, 'fake');
  });
}
