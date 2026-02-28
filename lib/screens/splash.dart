import 'package:exeat_system/services/initialization_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exeat_system/screens/login_screen__student.dart';
import 'package:exeat_system/screens/home_page.dart';
import 'package:exeat_system/screens/admin_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    print('🚀 Initializing app...');

    try {
      // Wait for Firebase
      await Future.delayed(const Duration(milliseconds: 500));

      // Initialize services
      final initializationService = Get.find<InitializationService>();
      await initializationService.ensureInitialized();

      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;

      print('🔍 Current user: ${user?.email ?? "No user logged in"}');

      if (user != null) {
        print('✅ User already logged in: ${user.email}');
        // Navigate to appropriate screen based on user type
        final isStudent = await _checkIfStudent(user.uid);
        print('📱 User type: ${isStudent ? "Student" : "Admin"}');

        if (isStudent) {
          Get.offAll(() => const HomePage());
        } else {
          Get.offAll(() => const AdminDashboard());
        }
      } else {
        print('❌ No user logged in, going to LoginScreen');
        Get.offAll(() => const LoginScreen());
      }
    } catch (e) {
      print('❌ Error in SplashScreen initialization: $e');
      print('🔄 Going to LoginScreen due to error');
      Get.offAll(() => const LoginScreen());
    } finally {
      _isInitialized = true;
    }
  }

  Future<bool> _checkIfStudent(String userId) async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(userId)
          .get();

      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(userId)
          .get();

      // If user exists in students collection and not in admins, they're a student
      if (studentDoc.exists && !adminDoc.exists) {
        return true;
      }

      // If user exists in admins collection, they're an admin
      if (adminDoc.exists) {
        return false;
      }

      // Default to student if not found in either (shouldn't happen)
      return true;
    } catch (e) {
      print('❌ Error checking user type: $e');
      return true; // Default to student on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff060121),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff060121),
                    Color(0xff2d1b5e),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff060121).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.school,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            const Text(
              'Exeat Management System',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isInitialized ? 'Redirecting...' : 'Loading...',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            if (!_isInitialized)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ElevatedButton(
                  onPressed: () {
                    print('🚀 Manual initialization triggered');
                    Get.offAll(() => const LoginScreen());
                  },
                  child: const Text('Go to Login'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
