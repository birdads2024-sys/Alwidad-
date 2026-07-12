import 'package:flutter/foundation.dart';
import 'package:no_screenshot/no_screenshot.dart';

class ScreenSecurityService {
  /// تفعيل الحماية (منع لقطات الشاشة وتسجيل الشاشة)
  static Future<void> enableSecureMode() async {
    if (!kIsWeb) {
      try {
        await NoScreenshot.instance.screenshotOff();
      } catch (e) {
        debugPrint('Error enabling screen security: $e');
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
