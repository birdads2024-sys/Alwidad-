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

  /// إبقاء الشاشة مضاءة ومنع القفل التلقائي أثناء التحميل
  static Future<void> setKeepScreenOn(bool enable) async {
    if (kIsWeb) return;
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('setKeepScreenOn', {'enable': enable});
      }
    } catch (e) {
      debugPrint('Error in setKeepScreenOn: $e');
    }
  }

  /// بدء مهمة في الخلفية على نظام iOS لإبقاء التحميل مستمراً عند قفل الشاشة
  static Future<int?> startBackgroundTask() async {
    if (kIsWeb || !Platform.isIOS) return null;
    try {
      final taskId = await _channel.invokeMethod<int>('startBackgroundTask');
      return taskId;
    } catch (e) {
      debugPrint('Error starting background task: $e');
      return null;
    }
  }

  /// إنهاء مهمة الخلفية على iOS
  static Future<void> endBackgroundTask(int? taskId) async {
    if (kIsWeb || !Platform.isIOS || taskId == null) return;
    try {
      await _channel.invokeMethod('endBackgroundTask', {'id': taskId});
    } catch (e) {
      debugPrint('Error ending background task: $e');
    }
  }
}

