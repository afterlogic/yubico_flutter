import 'dart:async';
import 'package:pigeon/pigeon.dart';
import 'package:flutter/services.dart';

class YubicoFlutter {
  static const MethodChannel _channel = const MethodChannel('yubico_flutter');

  Future stopNfcDiscovery() {}

  Future stopUsbDiscovery() {}

  Stream usbListener() {}

  Stream hfcListener() {}
}
