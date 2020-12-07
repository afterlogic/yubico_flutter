import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class FidoAuthRequest extends FidoRequest {
  final String domainUrl;
  final double timeout;
  final String challenge;
  final String requestId;
  final String rpId;
  final List<String> credentials;

  FidoAuthRequest(
    Duration requestTimeout,
    this.domainUrl,
    this.timeout,
    this.challenge,
    this.requestId,
    this.rpId,
    this.credentials,
  ) : super(requestTimeout);

  @override
  Future<Map<String, dynamic>> _request() {
    return _yubico.authRequest(
      domainUrl,
      timeout,
      challenge,
      requestId,
      rpId,
      credentials,
      nfc: isNFC,
    );
  }
}

class FidoRegisterRequest extends FidoRequest {
  final String domainUrl;
  final double timeout;
  final String challenge;
  final String requestId;
  final String rpId;
  final String rpName;
  final String userId;
  final String name;
  final String displayName;
  final List<Map<String, dynamic>> pubKeyCredParams;
  final List<Map<String, dynamic>> allowCredentials;

  FidoRegisterRequest(
    Duration requestTimeout,
    this.domainUrl,
    this.timeout,
    this.challenge,
    this.requestId,
    this.rpId,
    this.rpName,
    this.userId,
    this.name,
    this.displayName,
    this.pubKeyCredParams,
    this.allowCredentials,
  ) : super(requestTimeout);

  @override
  Future<Map<String, dynamic>> _request() {
    return _yubico.registrationRequest(
      domainUrl,
      timeout,
      challenge,
      requestId,
      rpId,
      rpName,
      userId,
      name,
      displayName,
      pubKeyCredParams,
      allowCredentials,
      nfc: isNFC,
    );
  }
}

class _YubicoFlutter {
  static final instance = _YubicoFlutter._();
  static const MethodChannel _channel = const MethodChannel('yubico_flutter');

  // ignore: close_sinks
  final _ctrl = StreamController<KeyState>.broadcast();
  KeyState keyState;

  Stream<KeyState> get onState => _ctrl.stream;

  // ignore: close_sinks
  final _nfcCtrl = StreamController<KeyState>.broadcast();
  KeyState nfcKeyState;

  Stream<KeyState> get onNfcState => _nfcCtrl.stream;

  _YubicoFlutter._() {
    if (Platform.isIOS) {
      _channel.setMethodCallHandler(_methodCallHandler);
    }
  }

  Future _methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case "stateChange":
        final state = _toKeyState(call.arguments as int);
        keyState = state;
        return _ctrl.add(keyState);
      case "nfcStateChange":
        final state = _toNfcKeyState(call.arguments as int);
        nfcKeyState = state;
        return _nfcCtrl.add(nfcKeyState);
    }
  }

  Future startSession() async {
    if (Platform.isIOS) {
      return _channel.invokeMethod("startSession");
    }
  }

  Future startNfcSession(String message, String success) async {
    if (Platform.isIOS) {
      return _channel.invokeMethod("startNfcSession", [
        {
          "message": message,
          "success": success,
        }
      ]);
    }
  }

  Future stopSession() async {
    if (Platform.isIOS) {
      return _channel.invokeMethod("stopSession");
    }
  }

  Future stopNfcSession() async {
    if (Platform.isIOS) {
      return _channel.invokeMethod("stopNfcSession");
    }
  }

  Future<bool> supportNcf() {
    if (Platform.isIOS) {
      return _channel.invokeMethod("supportNcf");
    } else {
      throw "not supported";
    }
  }

  Future<Map<String, dynamic>> authRequest(
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
      if (Platform.isIOS) {
        return  Map.castFrom(map["attestation"] as Map);
      } else {
        return map.cast();
      }
    } catch (e) {
      if (e is PlatformException) {
        final code = int.tryParse(e.code) ?? 0;

        throw FidoErrorCase.values[code];
      }
      print(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registrationRequest(
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
          "domainUrl": domainUrl,
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
      return map.cast();
    } catch (e) {
      if (e is PlatformException) {
        final code = int.tryParse(e.code) ?? 0;

        throw FidoErrorCase.values[code];
      }
      print(e);
      rethrow;
    }
  }
}

abstract class FidoRequest extends Sink {
  final _yubico = _YubicoFlutter.instance;
  final Duration _requestTimeout;
  bool _isNFC;

  bool get isNFC => _isNFC;

  FidoRequest(this._requestTimeout);

  Future<bool> waitConnection(String message, String success) async {
    if (Platform.isIOS) {
      _yubico.startSession();
      await Future.delayed(Duration(milliseconds: 300));
      final completer = Completer<bool>();
      if (_yubico.keyState == KeyState.OPEN) {
        completer.complete(false);
      }
      _yubico.onState
          .firstWhere((element) => element == KeyState.OPEN)
          .then((value) => completer.complete(false));
      _yubico.onState
          .firstWhere((element) => element == KeyState.CLOSED)
          .then((value) => completer.completeError(CanceledByUser()));
      if (_yubico.keyState != KeyState.OPEN) {
        _yubico.startNfcSession(message, success);
        _yubico.onNfcState
            .firstWhere((element) => element == KeyState.OPEN)
            .then((value) => completer.complete(true));
        _yubico.onNfcState
            .firstWhere((element) => element == KeyState.CLOSED)
            .then((value) => completer.completeError(CanceledByUser()));
        if (_yubico.keyState == KeyState.OPEN) {
          completer.complete(false);
        } else if (_yubico.nfcKeyState == KeyState.OPEN) {
          completer.complete(true);
        }
      }
      _isNFC = await completer.future.timeout(_requestTimeout);
      if (_isNFC) {
        _YubicoFlutter.instance.stopSession();
      } else {
        _YubicoFlutter.instance.stopNfcSession();
      }
      return _isNFC;
    } else {
      return null;
    }
  }

  Future<Map<String, dynamic>> start() async {
    try {
      final result = await _request();
      return result;
    } catch (e) {
      rethrow;
    } finally {
      close();
    }
  }

  Future<Map<String, dynamic>> _request();

  @override
  void add(data) {}

  @override
  void close() {
    if (Platform.isIOS) {
      _YubicoFlutter.instance.stopSession();
      _YubicoFlutter.instance.stopNfcSession();
    }
  }
}

class CanceledByUser extends Error {}

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

KeyState _toNfcKeyState(int code) {
  switch (code) {
    case 0:
      return KeyState.CLOSED;

    case 2:
      return KeyState.OPEN;

    case 1:
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
enum FidoErrorCase {
  RequestFailed,
  EmptyResponse,
  Canceled,
  InvalidResult,
  ErrorResponse,
  MapError,
}
