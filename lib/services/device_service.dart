import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  String? _deviceIdCached;

  Future<String> getUniqueDeviceId() async {
    if (_deviceIdCached != null) {
      return _deviceIdCached!;
    }

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceId = '';

    try {
      if (kIsWeb) {
        deviceId = 'web_client';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id; // Unique ID on Android
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios_unknown_device';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceId = macInfo.systemGUID ?? 'macos_unknown_device';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceId = windowsInfo.deviceId;
      } else {
        deviceId = 'unknown_platform_device';
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      deviceId = 'fallback_device_id_${DateTime.now().millisecondsSinceEpoch}';
    }

    _deviceIdCached = deviceId;
    return deviceId;
  }
}
