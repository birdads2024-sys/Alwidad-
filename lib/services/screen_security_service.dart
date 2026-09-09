import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:no_screenshot/no_screenshot.dart';

class ScreenSecurityService {
  static const MethodChannel _channel = MethodChannel('com.alwidad.security');
  static final ValueNotifier<bool> isScreenCaptured = ValueNotifier<bool>(false);
  static bool _initialized = false;

  /// تهيئة مستمع تسجيل الشاشة لنظام iOS
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb && Platform.isIOS) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onScreenCaptureChanged') {
          final args = call.arguments as Map?;
          final captured = args?['isCaptured'] as bool? ?? false;
          isScreenCaptured.value = captured;
        }
      });
      checkScreenCapture();
    }
  }

  /// فحص مباشر لحالة تسجيل الشاشة
  static Future<bool> checkScreenCapture() async {
    if (kIsWeb || !Platform.isIOS) return false;
    try {
      final captured = await _channel.invokeMethod<bool>('isScreenCaptured') ?? false;
      isScreenCaptured.value = captured;
      return captured;
    } catch (e) {
      debugPrint('Error checking screen capture: $e');
      return false;
    }
  }

  /// تفعيل الحماية (منع لقطات الشاشة وتسجيل الشاشة)
  static Future<void> enableSecureMode() async {
    initialize();
    if (!kIsWeb) {
      try {
        await NoScreenshot.instance.screenshotOff();
      } catch (e) {
        debugPrint('Error enabling screen security: $e');
      }
      if (Platform.isIOS) {
        await checkScreenCapture();
      }
    }
  }

  /// إيقاف الحماية
  static Future<void> disableSecureMode() async {
    if (!kIsWeb) {
      try {
        await NoScreenshot.instance.screenshotOn();
      } catch (e) {
        debugPrint('Error disabling screen security: $e');
      }
    }
  }
}

