import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exeat_system/controllers/notification_controller.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/request_controller.dart';
import '../controllers/admin_notification_controller.dart';

class InitializationService extends GetxService {
  static InitializationService get instance => Get.find();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxBool _isInitialized = false.obs;
  bool get isInitialized => _isInitialized.value;

  @override
  void onInit() {
    super.onInit();
    print('🚀 InitializationService started');

    // Listen to auth state changes
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        print('👤 Auth state changed - User logged in: ${user.email}');
        _initializeUserControllers();
      } else {
        print('👤 Auth state changed - User logged out');
        _clearControllers();
      }
    });
  }

  Future<void> _initializeUserControllers() async {
    try {
      print('🔄 Initializing user controllers...');

      final user = _auth.currentUser;
      if (user == null) return;

      // Check if user is student or admin
      final isStudent = await _isStudentUser(user.uid);

      if (isStudent) {
        // Initialize student controllers
        await _initializeStudentControllers(user.uid);
      } else {
        // Initialize admin controllers
        await _initializeAdminControllers(user.uid);
      }

      _isInitialized.value = true;
      print('✅ User controllers initialized successfully');
    } catch (e) {
      print('❌ Error initializing user controllers: $e');
    }
  }

  Future<bool> _isStudentUser(String userId) async {
    try {
      final studentDoc =
          await _firestore.collection('students').doc(userId).get();
      return studentDoc.exists;
    } catch (e) {
      print('❌ Error checking user type: $e');
      return false;
    }
  }

  Future<void> _initializeStudentControllers(String userId) async {
    final requestController = Get.find<RequestController>();
    final notificationController = Get.find<StudentNotificationController>();

    // Clear any existing data
    requestController.clearRequests();

    // Initialize request controller
    await requestController.initializeForUser();

    // Start notification listener
    notificationController.startListening();
  }

  Future<void> _initializeAdminControllers(String userId) async {
    final notificationController = Get.find<AdminNotificationController>();

    // Refresh admin notifications
    await notificationController.refreshNotifications();
  }

  void _clearControllers() {
    print('🧹 Clearing controllers on logout');

    // Clear request controller using public method
    final requestController = Get.find<RequestController>();
    requestController.clearRequests();

    // Clear notification controllers using public methods
    Get.find<StudentNotificationController>().stopListening();
    Get.find<AdminNotificationController>().notifications.clear();

    _isInitialized.value = false;
  }

  // Call this when navigating to any main screen
  Future<void> ensureInitialized() async {
    if (!_isInitialized.value && _auth.currentUser != null) {
      await _initializeUserControllers();
    }
  }
}
