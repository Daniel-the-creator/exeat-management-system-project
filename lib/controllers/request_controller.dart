// controllers/request_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exeat_system/model/request_model.dart';
import 'package:exeat_system/services/exeat_service.dart';

class RequestController extends GetxController {
  static RequestController get instance => Get.find();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ExeatService _exeatService = ExeatService();

  // Stream subscription for proper cleanup
  StreamSubscription<QuerySnapshot>? _requestStream;

  // Reactive list of requests
  final RxList<RequestModel> _studentRequests = <RequestModel>[].obs;
  List<RequestModel> get studentRequests => _studentRequests;

  // Loading state
  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  // Error state
  final RxString _error = ''.obs;
  String get error => _error.value;

  // Track if controller is initialized
  final RxBool _isInitialized = false.obs;
  bool get isInitialized => _isInitialized.value;

  // Track if stream is active
  final RxBool _isStreamActive = false.obs;
  bool get isStreamActive => _isStreamActive.value;

  // Statistics getters
  int get totalRequests => _studentRequests.length;

  int get pendingCount =>
      _studentRequests.where((request) => request.status == 'pending').length;

  int get approvedCount =>
      _studentRequests.where((request) => request.status == 'approved').length;

  int get rejectedCount =>
      _studentRequests.where((request) => request.status == 'rejected').length;

  int get cancelledCount =>
      _studentRequests.where((request) => request.status == 'cancelled').length;

  // Get all stats in a map for easy access
  Map<String, int> get stats => {
        'total': totalRequests,
        'pending': pendingCount,
        'approved': approvedCount,
        'rejected': rejectedCount,
        'cancelled': cancelledCount,
      };

  @override
  void onInit() {
    super.onInit();
    print('🎯 RequestController initialized');
    // Auto-initialize when controller is created
    _autoInitialize();
  }

  @override
  void onClose() {
    _requestStream?.cancel();
    _isStreamActive.value = false;
    print('🔴 RequestController disposed');
    super.onClose();
  }

  // Auto-initialize when user is already logged in
  void _autoInitialize() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      print('👤 User already logged in, auto-initializing...');
      initializeForUser();
    } else {
      print('⚠️ No user logged in yet, waiting for login...');
    }
  }

  // Call this method after user logs in
  Future<void> initializeForUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('❌ No user authenticated for RequestController');
      _error.value = 'User not authenticated';
      return;
    }

    // Check if already initialized for this user
    if (_isInitialized.value) {
      print('✅ RequestController already initialized, skipping...');
      return;
    }

    print('🚀 Initializing RequestController for user: ${currentUser.uid}');

    try {
      _isLoading.value = true;
      update();

      // Cancel existing stream if any
      _requestStream?.cancel();
      _isStreamActive.value = false;

      // Fetch initial data
      await fetchStudentRequests();

      // Setup real-time listener
      setupRealtimeListener();

      _isInitialized.value = true;
      _isLoading.value = false;

      print('🎉 RequestController initialization complete!');
      print('📊 Loaded ${_studentRequests.length} requests');
      print('📈 Stats: $stats');

      update();
    } catch (e) {
      print('❌ Error initializing RequestController: $e');
      _error.value = 'Failed to initialize: $e';
      _isLoading.value = false;
      update();
    }
  }

  // Setup real-time listener
  void setupRealtimeListener() {
    print('🔔 Setting up real-time listener');

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('User not authenticated');
      _error.value = 'User not authenticated';
      return;
    }

    print('📡 Listening for user ID: ${currentUser.uid}');

    _requestStream = _firestore
        .collection('requests')
        .where('studentId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      print('📥 Received ${snapshot.docs.length} requests from Firestore');
      _isStreamActive.value = true;

      if (snapshot.docs.isEmpty) {
        print('📭 No requests found for user ${currentUser.uid}');
        _studentRequests.value = [];
        update();
        return;
      }

      try {
        final requests = snapshot.docs.map((doc) {
          return RequestModel.fromMap(doc.data(), doc.id);
        }).toList();

        _studentRequests.value = requests;
        print('✅ Updated requests list (${requests.length} items)');
        update(); // Notify listeners
      } catch (e) {
        print('❌ Error parsing requests: $e');
        _error.value = 'Error parsing data: $e';
        update();
      }
    }, onError: (error) {
      print('❌ Stream error: $error');
      _error.value = 'Failed to load requests: $error';
      _isStreamActive.value = false;
      update();
    });
  }

  // Fetch requests (for initial load)
  Future<void> fetchStudentRequests() async {
    try {
      print('📥 Fetching student requests...');
      _isLoading.value = true;
      _error.value = '';
      update();

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('❌ User not authenticated');
        _error.value = 'User not authenticated';
        return;
      }

      print('🔍 Querying Firestore for user ID: ${currentUser.uid}');

      final querySnapshot = await _firestore
          .collection('requests')
          .where('studentId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      print('📄 Firestore returned ${querySnapshot.docs.length} documents');

      if (querySnapshot.docs.isEmpty) {
        print('📭 No requests found in database');
        _studentRequests.value = [];
      } else {
        print('🔄 Processing ${querySnapshot.docs.length} documents');
        _studentRequests.value = querySnapshot.docs.map((doc) {
          return RequestModel.fromMap(doc.data(), doc.id);
        }).toList();
        print('✅ Successfully loaded ${_studentRequests.length} requests');
      }

      _isLoading.value = false;
      update();
    } catch (e) {
      print('❌ Error in fetchStudentRequests: $e');
      _isLoading.value = false;
      _error.value = 'Failed to fetch requests: $e';
      update();
      rethrow;
    }
  }

  // Submit new request
  Future<void> addRequest({
    required String destination,
    required String leaveDate,
    required String returnDate,
    required String leaveTime,
    required String returnTime,
    required String reason,
    required String phone,
    required String contactPerson,
    required String contactNumber,
    required String guardianApproval,
    required String priorityLevel,
  }) async {
    try {
      print('➕ Adding new request...');
      _isLoading.value = true;
      _error.value = '';
      update();

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print('📝 Creating request with ExeatService...');

      await _exeatService.createRequest(
        destination: destination,
        leaveDate: leaveDate,
        returnDate: returnDate,
        leaveTime: leaveTime,
        returnTime: returnTime,
        reason: reason,
        phone: phone,
        contactPerson: contactPerson,
        contactNumber: contactNumber,
        guardianApproval: guardianApproval,
        priorityLevel: priorityLevel,
      );

      print('✅ Request created successfully');

      // Refresh the list to show the new request
      await fetchStudentRequests();

      _isLoading.value = false;
      update();

      // Show success message
      Get.snackbar(
        'Success',
        'Exeat request submitted successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('❌ Error in addRequest: $e');
      _isLoading.value = false;
      _error.value = 'Failed to submit request: $e';
      update();

      Get.snackbar(
        'Error',
        'Failed to submit request: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
    }
  }

  // Cancel/withdraw request
  Future<void> cancelRequest(String requestId) async {
    try {
      _isLoading.value = true;
      update();

      await _exeatService.cancelRequest(
        requestId: requestId,
        studentId: _auth.currentUser?.uid ?? '',
      );

      // Update local list
      final index =
          _studentRequests.indexWhere((req) => req.requestId == requestId);
      if (index != -1) {
        _studentRequests[index] = _studentRequests[index].copyWith(
          status: 'cancelled',
          updatedAt: Timestamp.now(),
        );
      }

      _isLoading.value = false;
      update();

      Get.snackbar(
        'Success',
        'Request cancelled',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      _isLoading.value = false;
      _error.value = 'Failed to cancel request: $e';
      update();

      Get.snackbar(
        'Error',
        'Failed to cancel request: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
    }
  }

  // Refresh requests manually
  Future<void> refreshRequests() async {
    print('🔄 Manual refresh triggered');
    await fetchStudentRequests();

    // Also force update for any listeners
    update();

    Get.snackbar(
      'Refreshed',
      'Requests list updated',
      duration: const Duration(seconds: 1),
    );
  }

  // Get specific request by ID
  RequestModel? getRequestById(String requestId) {
    return _studentRequests.firstWhereOrNull(
      (req) => req.requestId == requestId,
    );
  }

  // Get requests by status
  List<RequestModel> getRequestsByStatus(String status) {
    return _studentRequests.where((req) => req.status == status).toList();
  }

  // Clear error
  void clearError() {
    _error.value = '';
    update();
  }

  // Force reinitialize (useful after login)
  void reinitialize() {
    _isInitialized.value = false;
    initializeForUser();
  }

  // ========== NEW METHODS FOR INITIALIZATION SERVICE ==========

  // Clear all requests and reset state
  void clearRequests() {
    print('🧹 Clearing all requests data');
    _requestStream?.cancel();
    _isStreamActive.value = false;
    _studentRequests.clear();
    _isInitialized.value = false;
    _isLoading.value = false;
    _error.value = '';
    update();
  }

  // Force refresh all data
  void forceRefresh() {
    print('🔄 Force refreshing all requests');
    clearRequests();
    initializeForUser();
  }
}
