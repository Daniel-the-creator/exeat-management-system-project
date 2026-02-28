import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exeat_system/services/statistics_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class AdminProfileController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StatisticsService _statsService = StatisticsService();

  var fullName = 'Admin User'.obs;
  var email = 'admin@example.com'.obs;
  var phone = '+234 123 456 7890'.obs;
  var role = ''.obs;
  var departmentName = ''.obs;
  var hallName = ''.obs;

  // Statistics
  var pendingCount = 0.obs;
  var approvedCount = 0.obs;
  var rejectedCount = 0.obs;
  var expiredCount = 0.obs;
  var totalCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadAdminProfile();
    loadStatistics();
  }

  Future<void> loadAdminProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final adminDoc =
          await _firestore.collection('admins').doc(user.uid).get();

      if (adminDoc.exists) {
        final data = adminDoc.data()!;
        fullName.value = data['name'] ?? 'Admin User';
        email.value = data['email'] ?? user.email ?? '';
        phone.value = data['phone'] ?? '';
        role.value = data['role'] ?? '';

        // Load department/hall names if available
        if (data['departmentId'] != null) {
          final deptDoc = await _firestore
              .collection('departments')
              .doc(data['departmentId'])
              .get();
          departmentName.value = deptDoc.data()?['name'] ?? '';
        }

        if (data['hallId'] != null) {
          final hallDoc =
              await _firestore.collection('halls').doc(data['hallId']).get();
          hallName.value = hallDoc.data()?['name'] ?? '';
        }
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to load admin profile: $e");
    }
  }

  Future<void> loadStatistics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final stats = await _statsService.getAdminStatistics(user.uid);

      pendingCount.value = stats['pending'] ?? 0;
      approvedCount.value = stats['approved'] ?? 0;
      rejectedCount.value = stats['rejected'] ?? 0;
      expiredCount.value = stats['expired'] ?? 0;
      totalCount.value = stats['total'] ?? 0;
    } catch (e) {
      Get.snackbar("Error", "Failed to load statistics: $e");
    }
  }

  Future<void> updateProfile({
    required String newName,
    required String newEmail,
    required String newPhone,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      await _firestore.collection('admins').doc(user.uid).update({
        'name': newName,
        'email': newEmail,
        'phone': newPhone,
        'updatedAt': Timestamp.now(),
      });

      // Update local values
      fullName.value = newName;
      email.value = newEmail;
      phone.value = newPhone;

      Get.snackbar(
        "Success",
        "Profile updated successfully!",
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to update profile: $e",
        snackPosition: SnackPosition.TOP,
      );
      rethrow;
    }
  }

  String getDisplayName() {
    return fullName.value.split(' ').first;
  }

  void refreshData() {
    loadAdminProfile();
    loadStatistics();
  }
}
