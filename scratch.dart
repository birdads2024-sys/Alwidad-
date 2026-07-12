import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

void main() async {
  final orgId = "64c6cbb6554ec6e3e9ec51a7"; // From DRM Credentials screenshot
  final assetId = "64d28c927e5821954062dab2"; // The 8-second video
  final signSecret = "2c3d7d427565aa2a60f451355ec8451e"; // URL Signing Secret from screenshot
  
  final expires = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
  
  final stringToSign = "/$orgId/$assetId?expires=$expires";
  
  // Try 1: UTF8 encode
  var hmac1 = Hmac(sha1, utf8.encode(signSecret));
  var digest1 = hmac1.convert(utf8.encode(stringToSign));
  
  // Try 2: hex decode? No, let's try base64 decode if valid
  String digest2 = "";
  try {
    var hmac2 = Hmac(sha1, base64Decode(signSecret));
    digest2 = hmac2.convert(utf8.encode(stringToSign)).toString();
  } catch (e) {
    digest2 = "invalid base64";
  }
  
  // Try sending requests
  final urls = [
    "https://widevine.gumlet.com/licence/$orgId/$assetId?expires=$expires&token=$digest1",
    "https://widevine.gumlet.com/licence/$orgId/$assetId?expires=$expires&token=$digest2"
  ];
  
  for (int i=0; i<urls.length; i++) {
    print("Testing URL ${i+1}...");
    try {
      final response = await http.post(Uri.parse(urls[i]), body: "dummy_challenge");
      print("Response ${i+1}: ${response.statusCode} - ${response.body}");
    } catch (e) {
      print("Error ${i+1}: $e");
    }
  }
}
