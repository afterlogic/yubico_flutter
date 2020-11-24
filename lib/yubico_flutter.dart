import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class YubicoFlutter {
  static final instance = YubicoFlutter._();
  static const MethodChannel _channel = const MethodChannel('yubico_flutter');
  KeyState keyState;

  // ignore: close_sinks
  final _ctrl = StreamController.broadcast<KeyState>();

  Stream<KeyState> get onState => _ctrl.stream;

  YubicoFlutter._() {
    if (Platform.isIOS) {
      _channel.setMethodCallHandler(_methodCallHandler);
    }
  }

  Future _methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case "stateChange":
        final state = _toKeyState(call.arguments as int);
        keyState = state;
        _ctrl.add(keyState);
    }
  }

  Future startSession() async {
    if (Platform.isIOS) {
      return _channel.invokeMethod("startSession");
    }
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
          "domainUrl": domainUrl,
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
      if (e is PlatformException) {}
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
    List<Map<String, dynamic>> pubKeyCredParams,
    List<Map<String, dynamic>> allowCredentials, {
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
          "allowCredentials": allowCredentials,
          "nfc": nfc,
        }
      ]);
      print(map);
      return map;
    } catch (e) {
      if (e is PlatformException) {}
      print(e);
    }
  }
}

KeyState _toKeyState(int code) {
  switch (code) {
    case 0:
      return KeyState.CLOSED;

    case 1:
      return KeyState.OPEN;

    case 2:
      return KeyState.CLOSING;

    case 3:
      return KeyState.OPENING;
  }
  return null;
}

enum KeyState {
  /// The session is closed. No commands can be sent to the key.
  /// 0
  CLOSED,

  /// The session is opened and ready to use. The application can send immediately commands to the key.
  /// 1
  OPEN,

  /// The session is in an intermediary state between opened and closed. The application should not send commands
  /// to the key when the session is in this state.
  /// 2
  CLOSING,

  /// The session is in an intermediary state between closed and opened. The application should not send commands
  /// to the key when the session is in this state.
  /// 3
  OPENING,
}

enum IOSError {
  Undefined,
  EmptyResult,
  NotAttached,
  NfcNotSupported,
}
