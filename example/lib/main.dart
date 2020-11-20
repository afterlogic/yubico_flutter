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
              onPressed: request,
            ),
            FlatButton(
              child: Text("auth"),
              onPressed: () {},
            ),
          ],
        )),
      ),
    );
  }

  request() async {
    final response = await post(
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
    final map = jsonDecode(response.body)["Result"]["publicKey"];
    print(map);
    YubicoFlutter.registrationRequest(
      (map["timeout"] as num).toDouble(),
      map["challenge"],
      null,
      map["rp"]["id"],
      map["rp"]["name"],
      map["user"]["id"],
      map["user"]["name"],
      map["user"]["displayName"],
      (map["pubKeyCredParams"] as List).cast(),
    );
  }
}
