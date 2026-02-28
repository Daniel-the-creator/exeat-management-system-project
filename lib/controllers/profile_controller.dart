import 'package:exeat_system/model/user_model.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileController extends GetxController {
  static ProfileController get instance => Get.find();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Observable user data - MAKE SURE TO RESET ON LOGOUT
  final Rx<UserModel?> _currentUser = Rx<UserModel?>(null);
  UserModel? get currentUser => _currentUser.value;

  // Reactive values for profile
  final RxString fullName = ''.obs;
  final RxString email = ''.obs;
  final RxString phone = ''.obs;
  final RxString matric = ''.obs;
  final RxString department = ''.obs;
  final RxString hall = ''.obs;
  final RxString role = ''.obs;

  // Add a listener for auth state changes
  @override
  void onInit() {
    super.onInit();

    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        // User logged in or changed
        fetchUserData();
      } else {
        // User logged out - CLEAR ALL DATA
        _clearUserData();
      }
    });

    // Also fetch initially if user is already logged in
    if (_auth.currentUser != null) {
      fetchUserData();
    }
  }

  // Fetch user data from Firestore
  Future<void> fetchUserData() async {
    try {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        _clearUserData();
        return;
      }

      print('Fetching data for user: ${firebaseUser.uid}');

      // Try to fetch from students collection first
      DocumentSnapshot? userDoc = await _getUserDocument(firebaseUser.uid);

      if (userDoc != null && userDoc.exists) {
        final user = UserModel.fromFirestore(userDoc);
        _currentUser.value = user;

        // Update reactive values
        fullName.value = user.fullName;
        email.value = user.email;
        phone.value = user.phone;
        matric.value = user.matricNo ?? '';
        department.value = user.department ?? '';
        hall.value = user.hall ?? '';
        role.value = user.role;

        print('User data loaded: ${user.fullName}');
      } else {
        print('No user document found');
        _clearUserData();
      }
    } catch (e) {
      print('Error fetching user data: $e');
      _clearUserData();
    }
  }

  // Helper method to get user document from either students or admins collection
  Future<DocumentSnapshot?> _getUserDocument(String uid) async {
    try {
      // Try students collection first
      DocumentSnapshot studentDoc =
          await _firestore.collection('students').doc(uid).get();

      if (studentDoc.exists) {
        print('Found user in students collection');
        return studentDoc;
      }

      // If not found in students, try admins collection
      DocumentSnapshot adminDoc =
          await _firestore.collection('admins').doc(uid).get();

      if (adminDoc.exists) {
        print('Found user in admins collection');
        return adminDoc;
      }

      print('User not found in any collection');
      return null;
    } catch (e) {
      print('Error getting user document: $e');
      return null;
    }
  }

  // CLEAR ALL USER DATA - IMPORTANT!
  void _clearUserData() {
    print('Clearing user data...');

    _currentUser.value = null;
    fullName.value = '';
    email.value = '';
    phone.value = '';
    matric.value = '';
    department.value = '';
    hall.value = '';
    role.value = '';

    print('User data cleared');
  }

  // Method to manually refresh data (call this after login)
  Future<void> refreshUserData() async {
    print('Manually refreshing user data...');
    await fetchUserData();
  }

  // Update profile information
  Future<void> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    try {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return;

      // Determine which collection to update
      String collectionName =
          currentUser?.isStudent == true ? 'students' : 'admins';

      await _firestore.collection(collectionName).doc(firebaseUser.uid).update({
        'name': fullName,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local values
      this.fullName.value = fullName;
      this.phone.value = phone;

      // Refresh data
      await fetchUserData();
    } catch (e) {
      throw e.toString();
    }
  }

  // Check if user is admin
  bool get isAdmin => currentUser?.isAdmin == true;

  // Check if user is student
  bool get isStudent => currentUser?.isStudent == true;

  // Get user role display name
  String get roleDisplay {
    switch (currentUser?.role) {
      case 'student':
        return 'Student';
      case 'hod':
        return 'Head of Department';
      case 'student_affairs':
        return 'Student Affairs';
      case 'hall_warden':
        return 'Hall Warden';
      case 'super_admin':
        return 'Super Administrator';
      default:
        return 'User';
    }
  }

  void clearData() {}
}
