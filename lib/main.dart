import 'package:exeat_system/controllers/admin_notification_controller.dart';
import 'package:exeat_system/controllers/notification_controller.dart';
import 'package:exeat_system/screens/splash.dart';
import 'package:exeat_system/services/initialization_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:exeat_system/screens/firebase_options.dart';

// Import controllers
import 'package:exeat_system/controllers/profile_controller.dart';
import 'package:exeat_system/controllers/request_controller.dart';
import 'package:exeat_system/controllers/admin_profile_controller.dart';
import 'package:exeat_system/controllers/request_admin_controller.dart';

void main() async {
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Exeat Management System',
      theme: ThemeData(
        fontFamily: 'Montserrat',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff060121),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff060121),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xff060121),
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xff060121),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ),
      initialBinding: AppBindings(),
      home: const SplashScreen(),
      defaultTransition: Transition.cupertino,
      enableLog: true,
      logWriterCallback: (text, {bool isError = false}) {
        if (isError) {
          print('[GETX ERROR] $text');
        } else {
          print('[GETX] $text');
        }
      },
    );
  }
}

// Create AppBindings with proper initialization order
class AppBindings extends Bindings {
  @override
  void dependencies() {
    print('🔧 Initializing AppBindings...');

    // Initialize controllers in order
    Get.lazyPut(() => ProfileController(), fenix: true);
    Get.lazyPut(() => RequestController(), fenix: true);
    Get.lazyPut(() => RequestAdminController(), fenix: true);
    Get.lazyPut(() => AdminProfileController(), fenix: true);
    Get.lazyPut(() => StudentNotificationController(), fenix: true);
    Get.lazyPut(() => AdminNotificationController(), fenix: true);
    Get.lazyPut(() => InitializationService(), fenix: true);

    print('✅ All controllers registered with GetX');
  }
}
