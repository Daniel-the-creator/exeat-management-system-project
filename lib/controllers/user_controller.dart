// controllers/user_controller.dart
import 'package:exeat_system/model/user_model.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserController extends GetxController {
  static UserController get instance => Get.find();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Reactive user data
  final Rx<UserModel?> _currentUser = Rx<UserModel?>(null);
  UserModel? get currentUser => _currentUser.value;

  @override
  void onInit() {
    super.onInit();
    fetchUserData();
  }

  // Fetch user data from Firestore
  Future<void> fetchUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          _currentUser.value = UserModel.fromFirestore(userDoc);
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? profileImage,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        Map<String, dynamic> updates = {};
        if (fullName != null) updates['fullName'] = fullName;
        if (phone != null) updates['phone'] = phone;
        if (profileImage != null) updates['profileImage'] = profileImage;

        await _firestore.collection('users').doc(user.uid).update(updates);

        await fetchUserData(); // Refresh data
      }
    } catch (e) {
      throw e.toString();
    }
  }

  // Get user data for specific user ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }
}
