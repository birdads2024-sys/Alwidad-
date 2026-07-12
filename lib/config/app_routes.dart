import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/device_mismatch_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/admin/admin_main_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot_password';
  static const String home = '/home'; // Student Main Navigation
  static const String adminHome = '/admin'; // Admin dashboard
  static const String deviceMismatch = '/device_mismatch'; // Lock warning
  static const String demoVideos = '/demo_videos'; // Redirected to main navigation

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    home: (context) => const MainNavigationScreen(),
    adminHome: (context) => const AdminMainScreen(),
    deviceMismatch: (context) => const DeviceMismatchScreen(),
    demoVideos: (context) => const MainNavigationScreen(),
  };
}
