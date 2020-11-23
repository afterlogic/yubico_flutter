import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class YubicoFlutter {
  static final instance = YubicoFlutter._();

  static const MethodChannel _channel = const MethodChannel('yubico_flutter');

  YubicoFlutter._() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  Future _methodCallHandler(MethodCall call) {
    switch (call.method) {
      case "stateChange":
        final state = call.arguments as int;
        print(state);
    }
  }

  Future startSession() {
    return _channel.invokeMethod("startSession");
  }

  Future<bool> supportNcf() {
    if (Platform.isIOS) {
      return _channel.invokeMethod("supportNcf");
    } else {
      throw "not supported";
    }
  }

  Future authRequest(
      String domainUrl,
    double timeout,
    String challenge,
    String requestId,
    String rpId,
    List<String> credentials, {
    bool nfc = false,
  }) async {
    try {
      final map = await _channel.invokeMapMethod("authRequest", [
        {
          "timeout": timeout,
          "domainUrl":domainUrl,
          "challenge": challenge,
          "requestId": requestId,
          "rpId": rpId,
          "credentials": credentials,
          "nfc": nfc,
        }
      ]);
      print(map);
      return map;
    } catch (e) {
      print(e);
    }
  }

  Future<Map> registrationRequest(
      String domainUrl,
      double timeout,
    String challenge,
    String requestId,
    String rpId,
    String rpName,
    String userId,
    String name,
    String displayName,
    List<Map<String, dynamic>> pubKeyCredParams, {
    bool nfc = false,
  }) async {
    try {
      final map = await _channel.invokeMapMethod("registrationRequest", [
        {
          "timeout": timeout,
          "challenge": challenge,
          "requestId": requestId,
          "rpId": rpId,
          "rpName": rpName,
          "userId": userId,
          "name": name,
          "displayName": displayName,
          "pubKeyCredParams": pubKeyCredParams,
          "nfc": nfc,
        }
      ]);
      print(map);
      return map;
    } catch (e) {
      print(e);
    }
  }
}

class KeyState {
  /// The session is closed. No commands can be sent to the key.
  static const closed = 0;

  /// The session is opened and ready to use. The application can send immediately commands to the key.
  static const open = 1;

  /// The session is in an intermediary state between opened and closed. The application should not send commands
  /// to the key when the session is in this state.
  static const closing = 2;

  /// The session is in an intermediary state between closed and opened. The application should not send commands
  /// to the key when the session is in this state.
  static const opening = 3;
}
