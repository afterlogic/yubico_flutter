import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:yubico_flutter/yubico_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    test();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlatButton(
              child: Text("registration"),
              onPressed: registerRequest,
            ),
            FlatButton(
              child: Text("auth"),
              onPressed: authRequest,
            ),
          ],
        )),
      ),
    );
  }

  test() async {
    final response = await get("https://test.afterlogic.com/.well-known/assetlinks.json");
    print(response.body);
  }

  registerRequest() async {
    final response1 = await post(
      "https://test.afterlogic.com/?/Api/",
      headers: {
        "Authorization":
            "Bearer l5wOgQ5iQwtudpdNvGBRU1xu44ssgDMGL2AVblvv01aHuMW8kOqb6_HPuYzrTT7xNBDxYlP-jq74ZZ0DFyn0mD0HvgNTrg0yaUv895otGtWmxuGx2pIddiwKwoPPBhH2wJzDqHToS_IrIpLgyaoxARvfjs06zh-iL-8o1cStQKzAvVIWXkU62zxcc_IWg-WDsgnRmx976yS253eBE2yuTqIoDbhQne7ANOD3iXa8rQM7qP__OgJeYg_tQ3TnHVyYk0aWHB-c8XGqGwZLOeTMi28UtH0"
      },
      body: {
        "Module": "TwoFactorAuth",
        "Method": "RegisterSecurityKeyAuthenticatorBegin",
        "Parameters": jsonEncode({"Password": "p12345q"}),
      },
    );
    final map = jsonDecode(response1.body)["Result"]["publicKey"];
    print(map);

    final fidoRequest = FidoRegisterRequest(
      Duration(seconds: 30),
      "https://test.afterlogic.com",
      (map["timeout"] as num).toDouble(),
      map["challenge"],
      null,
      map["rp"]["id"],
      map["rp"]["name"],
      map["user"]["id"],
      map["user"]["name"],
      map["user"]["displayName"],
      (map["pubKeyCredParams"] as List).cast(),
      (map["allowCredentials"] as List)?.cast(),
    );
    final keyResponse = await fidoRequest.start("Connect your key", "Success");
    fidoRequest.close();
    final response2 = await post(
      "https://test.afterlogic.com/?/Api/",
      headers: {
        "Authorization":
            "Bearer l5wOgQ5iQwtudpdNvGBRU1xu44ssgDMGL2AVblvv01aHuMW8kOqb6_HPuYzrTT7xNBDxYlP-jq74ZZ0DFyn0mD0HvgNTrg0yaUv895otGtWmxuGx2pIddiwKwoPPBhH2wJzDqHToS_IrIpLgyaoxARvfjs06zh-iL-8o1cStQKzAvVIWXkU62zxcc_IWg-WDsgnRmx976yS253eBE2yuTqIoDbhQne7ANOD3iXa8rQM7qP__OgJeYg_tQ3TnHVyYk0aWHB-c8XGqGwZLOeTMi28UtH0"
      },
      body: {
        "Module": "TwoFactorAuth",
        "Method": "RegisterSecurityKeyAuthenticatorFinish",
        "Parameters":
            jsonEncode({"Password": "p12345q", "Attestation": keyResponse["attestation"]}),
      },
    );
    print(jsonDecode(response2.body));
  }

  authRequest() async {
    final response1 = await post(
      "https://test.afterlogic.com/?/Api/",
      body: {
        "Module": "TwoFactorAuth",
        "Method": "VerifySecurityKeyBegin",
        "Parameters": jsonEncode({"Login": "n.yakovlev@afterlogic.com", "Password": "p12345q"}),
      },
    );
    final map = jsonDecode(response1.body)["Result"]["publicKey"];
    print(map);

    final fidoRequest = FidoAuthRequest(
      Duration(seconds: 30),
      "https://test.afterlogic.com",
      (map["timeout"] as num).toDouble(),
      map["challenge"],
      null,
      map["rpId"],
      (map["allowCredentials"] as List).map((e) => e["id"] as String).toList(),
    );
    final keyResponse = await fidoRequest.start("Connect your key", "Success");
    fidoRequest.close();
    final response2 = await post(
      "https://test.afterlogic.com/?/Api/",
      body: {
        "Module": "TwoFactorAuth",
        "Method": "VerifySecurityKeyFinish",
        "Parameters": jsonEncode({
          "Login": "n.yakovlev@afterlogic.com",
          "Password": "p12345q",
          "Attestation": keyResponse["attestation"]
        }),
      },
    );
    print(jsonDecode(response2.body));
  }
}
