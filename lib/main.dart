import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';
import 'config/firebase_options.dart';
import 'models/download_task_model.dart';
import 'services/download_manager_service.dart';
import 'providers/auth_provider.dart';
import 'providers/courses_provider.dart';
import 'providers/admin_students_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  try {
    await Hive.initFlutter();
    Hive.registerAdapter(DownloadTaskModelAdapter());
  } catch (e) {
    debugPrint('Hive init error: $e');
  }
  
  final downloadService = DownloadManagerService();
  try {
    await downloadService.init();
  } catch (e) {
    debugPrint('DownloadManagerService init error: $e');
  }

  final coursesProvider = CoursesProvider();
  try {
    await coursesProvider.init();
  } catch (e) {
    debugPrint('CoursesProvider init error: $e');
  }

  final authProvider = AuthProvider();
  try {
    await authProvider.checkCurrentUser().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('authProvider.checkCurrentUser timed out during main()');
      },
    );
  } catch (e) {
    debugPrint('AuthProvider checkCurrentUser error: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: coursesProvider),
        ChangeNotifierProvider(create: (_) => AdminStudentsProvider()),
      ],
      child: const AlwidadApp(),
    ),
  );
}
