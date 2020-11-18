import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yubico_flutter/yubico_flutter.dart';

void main() {
  const MethodChannel channel = MethodChannel('yubico_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await YubicoFlutter.platformVersion, '42');
  });
}
