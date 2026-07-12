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
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );



  await Hive.initFlutter();

  Hive.registerAdapter(DownloadTaskModelAdapter());
  
  final downloadService = DownloadManagerService();
  await downloadService.init();

  final coursesProvider = CoursesProvider();
  await coursesProvider.init();

  final authProvider = AuthProvider();
  await authProvider.checkCurrentUser();
  
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
