import 'dart:async';
import 'package:flutter/services.dart';

class YubicoFlutter {
  static const MethodChannel _channel = const MethodChannel('yubico_flutter');

  YubicoFlutter._();

  static Future authRequest(
    double timeout,
    String challenge,
    String requestId,
    String rpId,
    List<String> credentials,
  ) async {
    try {
      final map = await _channel.invokeMapMethod("authRequest", [
        {
          "timeout": timeout,
          "challenge": challenge,
          "requestId": requestId,
          "rpId": rpId,
          "credentials": credentials,
        }
      ]);
      print(map);
    } catch (e) {
      print(e);
    }
  }

  static Future registrationRequest(
    double timeout,
    String challenge,
    String requestId,
    String rpId,
    String rpName,
    String userId,
    String name,
    String displayName,
    List<Map<String, dynamic>> pubKeyCredParams,
  ) async {
    try {
      int retryCount = 3;
      while (true) {
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
            }
          ]);
          print(map);
          return;
        } catch (e) {
          retryCount--;
          if (retryCount < 0) {
            rethrow;
          }
        }
      }
    } catch (e) {
      print(e);
    }
  }
}
