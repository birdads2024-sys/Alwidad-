import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/courses_provider.dart';
import '../services/device_service.dart';
import '../services/firestore_service.dart';
import '../config/app_constants.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/custom_snackbar.dart';
import 'student/home_screen.dart';
import 'student/courses_screen.dart';
import 'student/more_screen.dart';

import 'student/files_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Tabs mapping to separate student screen files
  final List<Widget> _tabs = [
    const StudentHomeScreen(),
    const CoursesScreen(),
    const FilesScreen(),
    const MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndBindDeviceId();
    });
  }

  Future<void> _checkAndBindDeviceId() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user != null && user.role == 'student' && user.deviceId.isEmpty) {
        final deviceId = await DeviceService().getUniqueDeviceId();
        await FirestoreService().updateUserField(user.uid, 'deviceId', deviceId);
        await authProvider.checkCurrentUser();
      }
    } catch (e) {
      debugPrint('Error binding device ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.primaryColor,
          unselectedItemColor: Colors.grey.shade500,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              activeIcon: Icon(Icons.menu_book_rounded),
              label: 'الكورسات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_open_rounded),
              activeIcon: Icon(Icons.folder_open_rounded),
              label: 'الملفات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_rounded),
              activeIcon: Icon(Icons.more_horiz_rounded),
              label: 'المزيد',
            ),
          ],
        ),
      ),
    );
  }
}
