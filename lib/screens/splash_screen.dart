import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart';
import 'auth/device_mismatch_screen.dart';
import 'admin/admin_main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    Future.delayed(Duration.zero, () {
      _checkAuthAndNavigate();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    final stopwatch = Stopwatch()..start();
    
    // Fetch and check current user status with fallback timeout
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.checkCurrentUser().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Splash checkCurrentUser timeout');
        },
      );
    } catch (e) {
      debugPrint('Splash checkCurrentUser error: $e');
    }
    
    final elapsedMs = stopwatch.elapsedMilliseconds;
    const minSplashDurationMs = 1200;
    
    if (elapsedMs < minSplashDurationMs) {
      await Future.delayed(Duration(milliseconds: minSplashDurationMs - elapsedMs));
    }
    
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isDeviceMismatch) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DeviceMismatchScreen()),
      );
    } else {
      final user = authProvider.currentUserModel;
      if (user != null) {
        if (user.role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminMainScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Image.asset(
          'assets/splash_screen.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
