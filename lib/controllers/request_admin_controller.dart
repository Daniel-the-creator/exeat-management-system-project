// controllers/request_admin_controller.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exeat_system/model/exeat_request.dart';
import 'package:exeat_system/model/request_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class RequestAdminController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _allRequestsStream;

  // Observable lists
  var allRequests = <RequestModel>[].obs;
  var pendingRequests = <RequestModel>[].obs;
  var approvedRequests = <RequestModel>[].obs;
  var rejectedRequests = <RequestModel>[].obs;
  var completedRequests = <RequestModel>[].obs;

  // Admin info
  final RxString adminRole = ''.obs;
  final RxString adminHallId = ''.obs;
  final RxString adminDepartmentId = ''.obs;
  final RxString adminId = ''.obs;

  // Filtering and search
  var searchQuery = ''.obs;
  var selectedStatus = 'all'.obs;
  var selectedPriority = 'all'.obs;
  var sortBy = 'createdAt'.obs;
  var sortAscending = false.obs;

  // Statistics
  var totalCount = 0.obs;
  var pendingCount = 0.obs;
  var approvedCount = 0.obs;
  var declinedCount = 0.obs;

  // Loading states
  var isLoading = false.obs;
  var isExporting = false.obs;
  var isInitialized = false.obs;

  // Navigation tracking
  final RxString currentScreen = ''.obs;
  final RxList<String> navigationStack = <String>[].obs;

  // Computed properties
  List<ExeatRequest> get exeatPendingRequests => pendingRequests
      .map((request) => _convertToExeatRequest(request))
      .toList();

  List<ExeatRequest> get exeatApprovedRequests => approvedRequests
      .map((request) => _convertToExeatRequest(request))
      .toList();

  List<ExeatRequest> get exeatRejectedRequests => rejectedRequests
      .map((request) => _convertToExeatRequest(request))
      .toList();

  @override
  void onInit() {
    super.onInit();
    print('🔄 RequestAdminController onInit called');
    _initializeController();
  }

  Future<void> _initializeController() async {
    try {
      isInitialized.value = false;
      await debugAdminRole();
      await initializeRequestStream();
      isInitialized.value = true;
      print('✅ RequestAdminController initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize RequestAdminController: $e');
      Get.snackbar('Error', 'Failed to initialize: $e');
    }
  }

  @override
  void onClose() {
    print('🛑 RequestAdminController onClose called');
    _disposeStream();
    super.onClose();
  }

  void _disposeStream() {
    if (_allRequestsStream != null) {
      _allRequestsStream!.cancel();
      _allRequestsStream = null;
      print('📊 Request stream disposed');
    }
  }

  Future<void> initializeRequestStream() async {
    try {
      isLoading.value = true;

      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated admin user');
        isLoading.value = false;
        return;
      }

      adminId.value = user.uid;

      // Get admin data
      final adminDoc =
          await _firestore.collection('admins').doc(user.uid).get();

      if (!adminDoc.exists) {
        print('❌ Admin document not found');
        isLoading.value = false;
        return;
      }

      final adminData = adminDoc.data()!;
      adminRole.value = adminData['role'] as String? ?? '';
      adminHallId.value = adminData['hallId'] as String? ?? '';
      adminDepartmentId.value = adminData['departmentId'] as String? ?? '';

      print('✅ Admin Info:');
      print('   ID: ${adminId.value}');
      print('   Role: ${adminRole.value}');
      print('   Hall ID: ${adminHallId.value}');
      print('   Dept ID: ${adminDepartmentId.value}');

      // Cancel any existing stream
      _disposeStream();

      // Build query based on role
      Query<Map<String, dynamic>> query = _firestore.collection('requests');

      final role = _normalizeRole(adminRole.value);
      print('🔍 Building query for role: $role (original: ${adminRole.value})');

      // Apply role-based filtering
      if (role == 'student_affairs' || role == 'super_admin') {
        print('👑 Student Affairs/Super Admin - Querying ALL requests');
        // No whereIn filter - get everything!
      } else if (role == 'warden') {
        if (adminHallId.value.isNotEmpty) {
          print('🏠 Warden - Filtering by hall: ${adminHallId.value}');
          query = query.where('hallId', isEqualTo: adminHallId.value);

          // Warden sees pending_warden, approved, and rejected requests
          query = query.where('status', whereIn: [
            'pending_warden',
            'approved',
            'rejected',
            'cancelled', // Also include cancelled if needed
          ]);
        } else {
          print('⚠️ Hall Warden has no hallId assigned');
          // Check if hallId exists in admin document
          print('   Admin hallId from document: $adminHallId');
          allRequests.value = [];
          updateFilteredLists();
          updateStatistics();
          isLoading.value = false;
          return;
        }
      } else if (role == 'hod') {
        if (adminDepartmentId.value.isNotEmpty) {
          print('🏫 HOD - Filtering by department: ${adminDepartmentId.value}');
          query =
              query.where('departmentId', isEqualTo: adminDepartmentId.value);
          query = query.where('status', whereIn: [
            'pending_hod',
            'pending_student_affairs',
            'pending_warden',
            'approved',
            'rejected',
          ]);
        } else {
          print('⚠️ HOD has no departmentId assigned');
          allRequests.value = [];
          updateFilteredLists();
          updateStatistics();
          isLoading.value = false;
          return;
        }
      } else {
        print('⚠️ Unknown admin role: ${adminRole.value}');
        allRequests.value = [];
        updateFilteredLists();
        updateStatistics();
        isLoading.value = false;
        return;
      }

      // Order by creation date
      query = query.orderBy('createdAt', descending: true);

      print('🚀 Executing Firestore query...');

      // Listen to stream
      _allRequestsStream = query.snapshots().listen((snapshot) {
        print(
            '📥 ${adminRole.value} received ${snapshot.docs.length} requests');

        if (snapshot.docs.isEmpty) {
          print('ℹ️ No requests found for ${adminRole.value}');
        } else {
          print('📋 Sample requests for ${adminRole.value}:');
          for (int i = 0; i < snapshot.docs.length && i < 3; i++) {
            final doc = snapshot.docs[i];
            final data = doc.data();
            print('   $i: ${data['studentName']} - ${data['status']}');
          }
          if (snapshot.docs.length > 3) {
            print('   ... and ${snapshot.docs.length - 3} more');
          }
        }

        // Process requests
        final List<RequestModel> requests = snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
            .toList();

        allRequests.value = requests;
        updateFilteredLists();
        updateStatistics();

        print('📊 ${adminRole.value} Statistics:');
        print('   Total: ${totalCount.value}');
        print('   Pending: ${pendingCount.value}');
        print('   Approved: ${approvedCount.value}');
        print('   Declined: ${declinedCount.value}');
      }, onError: (error) {
        print('❌ ${adminRole.value} Error loading requests: $error');
        Get.snackbar('Error', 'Failed to load requests: $error');
        isLoading.value = false;
      });

      // Also do an initial fetch to debug
      await _debugInitialFetch(query);

      isLoading.value = false;
    } catch (e) {
      print('❌ Error in initializeRequestStream: $e');
      print('❌ Stack trace: ${e.toString()}');
      Get.snackbar('Error', 'Failed to initialize: $e');
      isLoading.value = false;
      rethrow;
    }
  }

  // Helper method to normalize role names
  String _normalizeRole(String role) {
    if (role.isEmpty) return role;

    final lowerRole = role.toLowerCase().trim();

    // Handle student affairs variations
    if (lowerRole.contains('student') && lowerRole.contains('affairs')) {
      return 'student_affairs';
    }

    // Handle HOD variations
    if (lowerRole.contains('hod') ||
        lowerRole.contains('head of department') ||
        lowerRole.contains('head')) {
      return 'hod';
    }

    // Handle warden
    if (lowerRole.contains('warden') ||
        lowerRole.contains('hall_warden') ||
        lowerRole.contains('hall warden')) {
      return 'warden';
    }

    // Handle super admin
    if (lowerRole.contains('super') ||
        lowerRole.contains('superadmin') ||
        lowerRole.contains('super_admin')) {
      return 'super_admin';
    }

    return lowerRole;
  }

  Future<void> _debugInitialFetch(Query<Map<String, dynamic>> query) async {
    try {
      print('🔍 Debug: Performing initial query fetch...');
      final initialSnapshot = await query.get();
      print(
          '🔍 Debug: Initial fetch returned ${initialSnapshot.docs.length} documents');

      if (initialSnapshot.docs.isNotEmpty) {
        print('🔍 Debug: First 3 documents:');
        for (int i = 0; i < initialSnapshot.docs.length && i < 3; i++) {
          final doc = initialSnapshot.docs[i];
          final data = doc.data();
          print('   $i: ${data['studentName']} - ${data['status']}');
        }
      } else {
        print('🔍 Debug: No documents returned.');
        final allRequestsSnapshot =
            await _firestore.collection('requests').get();
        print(
            '🔍 Debug: Total requests in database: ${allRequestsSnapshot.docs.length}');
      }
    } catch (e) {
      print('🔍 Debug: Error in initial fetch: $e');
    }
  }

  void updateFilteredLists() {
    final normalizedRole = _normalizeRole(adminRole.value);
    print('🔄 Updating filtered lists for role: $normalizedRole');

    // Clear all lists first
    pendingRequests.clear();
    approvedRequests.clear();
    rejectedRequests.clear();
    completedRequests.clear();

    // Show requests based on role
    if (normalizedRole == 'hod') {
      // HOD sees requests pending their approval
      pendingRequests.value = allRequests
          .where((request) => request.status == 'pending_hod')
          .toList();
      print('   HOD: Found ${pendingRequests.length} pending_hod requests');
    } else if (normalizedRole == 'student_affairs') {
      // Student Affairs sees requests pending their approval
      pendingRequests.value = allRequests
          .where((request) => request.status == 'pending_student_affairs')
          .toList();
      print(
          '   Student Affairs: Found ${pendingRequests.length} pending_student_affairs requests');
    } else if (normalizedRole == 'warden') {
      // Warden sees requests pending their approval
      pendingRequests.value = allRequests
          .where((request) => request.status == 'pending_warden')
          .toList();
      print(
          '   Warden: Found ${pendingRequests.length} pending_warden requests');
    } else if (normalizedRole == 'super_admin') {
      // Super Admin sees all pending requests
      pendingRequests.value = allRequests
          .where((request) => request.status.contains('pending'))
          .toList();
      print('   Super Admin: Found ${pendingRequests.length} pending requests');
    }

    // All roles see approved requests
    approvedRequests.value =
        allRequests.where((request) => request.status == 'approved').toList();
    print('   Approved: Found ${approvedRequests.length} approved requests');

    // All roles see rejected requests
    rejectedRequests.value =
        allRequests.where((request) => request.status == 'rejected').toList();
    print('   Rejected: Found ${rejectedRequests.length} rejected requests');

    // All roles see completed requests
    completedRequests.value =
        allRequests.where((request) => request.status == 'completed').toList();
    print('   Completed: Found ${completedRequests.length} completed requests');

    // Update the observable counts
    updateStatistics();

    // Force UI update
    update();
  }

  void updateStatistics() {
    final normalizedRole = _normalizeRole(adminRole.value);

    if (normalizedRole == 'hod') {
      pendingCount.value = allRequests
          .where((request) => request.status == 'pending_hod')
          .length;
    } else if (normalizedRole == 'student_affairs') {
      pendingCount.value = allRequests
          .where((request) => request.status == 'pending_student_affairs')
          .length;
    } else if (normalizedRole == 'warden') {
      pendingCount.value = allRequests
          .where((request) => request.status == 'pending_warden')
          .length;
    } else if (normalizedRole == 'super_admin') {
      pendingCount.value = allRequests
          .where((request) => request.status.contains('pending'))
          .length;
    } else {
      pendingCount.value = 0;
    }

    approvedCount.value =
        allRequests.where((request) => request.status == 'approved').length;

    declinedCount.value =
        allRequests.where((request) => request.status == 'rejected').length;

    totalCount.value = allRequests.length;

    print('📊 Statistics Updated for $normalizedRole:');
    print('   Total: ${totalCount.value}');
    print('   Pending: ${pendingCount.value}');
    print('   Approved: ${approvedCount.value}');
    print('   Declined: ${declinedCount.value}');
  }

  ExeatRequest _convertToExeatRequest(RequestModel request) {
    return ExeatRequest(
      id: request.requestId,
      studentId: request.studentId,
      studentName: request.studentName,
      studentMatric: request.studentMatric,
      destination: request.destination,
      leaveDate: request.leaveDate,
      returnDate: request.returnDate,
      reason: request.reason,
      status: request.status,
      priorityLevel: request.priorityLevel,
      studentEmail: request.studentEmail,
      studentPhone: request.studentPhone,
      contactPerson: request.contactPerson,
      contactNumber: request.contactNumber,
      guardianApproval: request.guardianApproval,
      leaveTime: request.leaveTime,
      returnTime: request.returnTime,
      adminNote: request.adminNote,
      processedBy: request.processedBy,
      createdAt: request.createdAt,
      processedAt: request.processedAt,
      updatedAt: request.updatedAt,
    );
  }

  // ===================== APPROVE/DECLINE METHODS =====================
  Future<void> approveExeatRequest(ExeatRequest request) async {
    return updateRequestStatus(
      requestId: request.id!,
      newStatus: 'approved',
      adminNote: 'Approved by ${adminRole.value}',
    );
  }

  Future<void> declineExeatRequest(ExeatRequest request) async {
    return updateRequestStatus(
      requestId: request.id!,
      newStatus: 'rejected',
      adminNote: 'Declined by ${adminRole.value}',
    );
  }

  Future<void> updateRequestStatus({
    required String requestId,
    required String newStatus,
    required String adminNote,
  }) async {
    try {
      isLoading.value = true;

      final user = _auth.currentUser;
      if (user == null) throw Exception('Admin not logged in');

      final requestRef = _firestore.collection('requests').doc(requestId);
      final doc = await requestRef.get();

      if (!doc.exists) throw Exception('Request not found');

      final data = doc.data() ?? {};
      final oldStatus = data['status'] ?? 'pending';
      final studentId = data['studentId'] ?? '';
      final hallId = data['hallId'] as String? ?? '';

      print('🔄 Updating request $requestId from $oldStatus to $newStatus');

      // GUARD: Once declined/rejected, it cannot be approved or moved to pending
      if (oldStatus == 'rejected') {
        throw Exception(
            'This request has been declined and cannot be approved or moved back to pending.');
      }

      String finalStatus = newStatus;
      String updatedAdminNote = adminNote;

      // Prepare update data
      Map<String, dynamic> updateData = {
        'status': finalStatus,
        'adminNote': updatedAdminNote,
        'processedBy': user.email,
        'processedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'approved') {
        final normalizedRole = _normalizeRole(adminRole.value);

        if (oldStatus == 'pending_hod' && normalizedRole == 'hod') {
          finalStatus = 'pending_student_affairs';
          updatedAdminNote =
              'Approved by HOD - Awaiting Student Affairs review';
          print('   HOD approved → moving to pending_student_affairs');

          // Track HOD approval
          updateData['hodApprovedBy'] = user.email;
          updateData['hodApprovedAt'] = FieldValue.serverTimestamp();
          updateData['status'] = finalStatus;
          updateData['adminNote'] = updatedAdminNote;
        } else if (oldStatus == 'pending_student_affairs' &&
            (normalizedRole == 'student_affairs' ||
                normalizedRole == 'super_admin')) {
          finalStatus = 'pending_warden';
          updatedAdminNote =
              'Approved by Student Affairs - Awaiting Hall Warden approval';
          print('   Student Affairs approved → moving to pending_warden');

          // Track Student Affairs approval
          updateData['studentAffairsApprovedBy'] = user.email;
          updateData['studentAffairsApprovedAt'] = FieldValue.serverTimestamp();
          updateData['status'] = finalStatus;
          updateData['adminNote'] = updatedAdminNote;
        } else if (oldStatus == 'pending_warden' &&
            (normalizedRole == 'warden' || normalizedRole == 'super_admin')) {
          finalStatus = 'approved';
          updatedAdminNote = 'Fully approved by Hall Warden';
          print('   Warden approved → moving to approved');

          // Track Warden approval
          updateData['wardenApprovedBy'] = user.email;
          updateData['wardenApprovedAt'] = FieldValue.serverTimestamp();
          updateData['fullyApprovedAt'] = FieldValue.serverTimestamp();
          updateData['status'] = finalStatus;
          updateData['adminNote'] = updatedAdminNote;
        } else if (normalizedRole == 'super_admin') {
          finalStatus = 'approved';
          updatedAdminNote = 'Direct approval by Super Admin';
          print('   Super Admin direct approval');

          // Track all approvals at once
          updateData['hodApprovedBy'] = 'Super Admin (Direct)';
          updateData['studentAffairsApprovedBy'] = 'Super Admin (Direct)';
          updateData['wardenApprovedBy'] = 'Super Admin (Direct)';
          updateData['fullyApprovedAt'] = FieldValue.serverTimestamp();
          updateData['status'] = finalStatus;
          updateData['adminNote'] = updatedAdminNote;
        }
      } else if (newStatus == 'rejected') {
        finalStatus = 'rejected';
        updatedAdminNote = 'Declined by ${adminRole.value}';
        print('   Request rejected');

        // Track who rejected
        updateData['rejectedBy'] = user.email;
        updateData['rejectedAt'] = FieldValue.serverTimestamp();
        updateData['status'] = finalStatus;
        updateData['adminNote'] = updatedAdminNote;
      }

      print('   Final status will be: $finalStatus');

      await requestRef.update(updateData);

      await _addToRequestHistory(
        requestId: requestId,
        studentId: studentId,
        action: 'STATUS_UPDATE',
        details:
            'Changed from $oldStatus to $finalStatus by ${adminRole.value}',
        adminNote: updatedAdminNote,
        adminId: user.uid,
        adminEmail: user.email ?? 'Unknown',
      );

      await _createNotification(
        recipientId: studentId,
        recipientType: 'student',
        requestId: requestId,
        oldStatus: oldStatus,
        newStatus: finalStatus,
        adminNote: updatedAdminNote,
      );

      if (finalStatus == 'pending_student_affairs') {
        await _notifyStudentAffairsAdmins(
          requestId: requestId,
          studentName: data['studentName'] ?? '',
          studentMatric: data['studentMatric'] ?? '',
        );
      } else if (finalStatus == 'pending_warden' && hallId.isNotEmpty) {
        await _notifyWardens(
          hallId: hallId,
          requestId: requestId,
          studentName: data['studentName'] ?? '',
          studentMatric: data['studentMatric'] ?? '',
        );
      } else if (finalStatus == 'rejected') {
        // Notify all admins involved that request was rejected
        await _notifyRejectedRequest(
          requestId: requestId,
          studentName: data['studentName'] ?? '',
          studentMatric: data['studentMatric'] ?? '',
          rejectedBy: adminRole.value,
          adminNote: updatedAdminNote,
        );
      }

      Get.snackbar(
        'Success',
        'Request status updated to ${finalStatus.toUpperCase().replaceAll('_', ' ')}',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );

      // Wait for Firebase update, then refresh
      print('⏳ Waiting for Firebase update...');
      await Future.delayed(const Duration(seconds: 1));

      // Force a complete refresh
      print('🔄 Refreshing request stream...');
      await refreshRequests();
    } catch (e) {
      print('❌ Error updating request status: $e');
      Get.snackbar('Error', 'Failed to update request: $e',
          snackPosition: SnackPosition.TOP);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _notifyStudentAffairsAdmins({
    required String requestId,
    required String studentName,
    required String studentMatric,
  }) async {
    try {
      print('🔔 NOTIFYING Student Affairs admins about request $requestId');

      // First, check if we're finding the current admin
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) {
        print('❌ Current admin not authenticated');
        return;
      }

      print('   Current admin ID: ${currentAdmin.uid}');
      print('   Current admin email: ${currentAdmin.email}');

      // Get current admin document to see their role
      final currentAdminDoc =
          await _firestore.collection('admins').doc(currentAdmin.uid).get();
      if (currentAdminDoc.exists) {
        final currentAdminData = currentAdminDoc.data()!;
        final currentAdminRole = currentAdminData['role'] as String? ?? '';
        print('   Current admin role from DB: $currentAdminRole');
      } else {
        print('❌ Current admin document not found in admins collection!');
      }

      // Find ALL admins
      final allAdminsSnapshot = await _firestore.collection('admins').get();

      print(
          '   Found ${allAdminsSnapshot.docs.length} total admins in database');

      List<QueryDocumentSnapshot<Map<String, dynamic>>> relevantAdmins = [];

      for (final adminDoc in allAdminsSnapshot.docs) {
        final adminData = adminDoc.data();
        final role = adminData['role'] as String? ?? '';
        final normalizedRole = _normalizeRole(role);
        final name = adminData['name'] as String? ?? 'Unknown';
        final email = adminData['email'] as String? ?? 'Unknown';

        print('   Admin: $name ($email)');
        print('     ID: ${adminDoc.id}');
        print('     Role: $role');
        print('     Normalized: $normalizedRole');

        if (normalizedRole == 'student_affairs' ||
            normalizedRole == 'super_admin') {
          relevantAdmins.add(adminDoc);
          print('     ✅ ADDED to relevant admins');
        }
        print('     ---');
      }

      print(
          '   Total relevant Student Affairs/Super Admins: ${relevantAdmins.length}');

      // Create notifications for all relevant admins
      for (final adminDoc in relevantAdmins) {
        final adminData = adminDoc.data();
        final adminRole = adminData['role'] as String? ?? 'Unknown';
        final adminName = adminData['name'] as String? ?? 'Unknown';

        print(
            '   📨 Creating notification for admin: ${adminDoc.id} ($adminName - $adminRole)');

        await _firestore.collection('notifications').add({
          'recipientId': adminDoc.id,
          'recipientType': 'admin',
          'type': 'NEW_REQUEST',
          'title': 'New Exeat Request Awaiting Your Approval',
          'message':
              '$studentName ($studentMatric) - Request approved by HOD, awaiting your review',
          'requestId': requestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('   ✅ Notified admin: $adminName (${adminDoc.id})');
      }

      // If no relevant admins were found, notify current admin as fallback
      if (relevantAdmins.isEmpty) {
        print('⚠️ No Student Affairs or Super Admin found in database!');
        print('📨 Creating fallback notification for current admin');
        await _firestore.collection('notifications').add({
          'recipientId': currentAdmin.uid,
          'recipientType': 'admin',
          'type': 'NEW_REQUEST',
          'title': 'New Exeat Request Awaiting Your Approval',
          'message':
              '$studentName ($studentMatric) - Request approved by HOD, awaiting your review',
          'requestId': requestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ Fallback notification created for admin ${currentAdmin.uid}');
      }
    } catch (e) {
      print('❌ Error notifying Student Affairs admins: $e');
      print('❌ Stack trace: ${e.toString()}');
    }
  }

  Future<void> _notifyWardens({
    required String hallId,
    required String requestId,
    required String studentName,
    required String studentMatric,
  }) async {
    try {
      print('🔔 Notifying wardens for hall $hallId about request $requestId');

      final wardensSnapshot = await _firestore
          .collection('admins')
          .where('hallId', isEqualTo: hallId)
          .get();

      print('   Found ${wardensSnapshot.docs.length} admins in hall $hallId');

      for (final wardenDoc in wardensSnapshot.docs) {
        final wardenRole =
            (wardenDoc.data()['role'] as String? ?? '').toLowerCase();
        final wardenName = wardenDoc.data()['name'] as String? ?? 'Unknown';

        if (wardenRole.contains('warden') || wardenRole.contains('hall')) {
          await _firestore.collection('notifications').add({
            'recipientId': wardenDoc.id,
            'recipientType': 'admin',
            'type': 'NEW_REQUEST',
            'title': 'Request Awaiting Your Approval',
            'message':
                '$studentName ($studentMatric) - Request approved by Student Affairs, awaiting your approval',
            'requestId': requestId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('   ✅ Notified warden: $wardenName (${wardenDoc.id})');
        }
      }
    } catch (e) {
      print('❌ Error notifying wardens: $e');
    }
  }

  Future<void> _notifyRejectedRequest({
    required String requestId,
    required String studentName,
    required String studentMatric,
    required String rejectedBy,
    required String adminNote,
  }) async {
    try {
      print('🔔 Notifying about rejected request $requestId');

      final requestRef = _firestore.collection('requests').doc(requestId);
      final doc = await requestRef.get();

      if (!doc.exists) return;

      final data = doc.data() ?? {};

      // Get all admins who were involved
      List<String> adminIdsToNotify = [];

      // Notify HOD if they approved it
      if (data['hodApprovedBy'] != null) {
        // Find HOD admin(s) for this department
        final departmentId = data['departmentId'] as String?;
        if (departmentId != null && departmentId.isNotEmpty) {
          final hodAdmins = await _firestore
              .collection('admins')
              .where('departmentId', isEqualTo: departmentId)
              .where('role', isGreaterThanOrEqualTo: 'hod')
              .get();

          for (final adminDoc in hodAdmins.docs) {
            adminIdsToNotify.add(adminDoc.id);
          }
        }
      }

      // Notify Student Affairs if they approved it
      if (data['studentAffairsApprovedBy'] != null) {
        final studentAffairsAdmins = await _firestore
            .collection('admins')
            .where('role', whereIn: [
          'Student Affairs',
          'student_affairs',
          'Super Admin'
        ]).get();

        for (final adminDoc in studentAffairsAdmins.docs) {
          if (!adminIdsToNotify.contains(adminDoc.id)) {
            adminIdsToNotify.add(adminDoc.id);
          }
        }
      }

      // Create notifications
      for (final adminId in adminIdsToNotify) {
        await _firestore.collection('notifications').add({
          'recipientId': adminId,
          'recipientType': 'admin',
          'type': 'REQUEST_REJECTED',
          'title': 'Request Rejected by $rejectedBy',
          'message':
              '$studentName ($studentMatric) - Request you approved has been rejected by $rejectedBy. Note: $adminNote',
          'requestId': requestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('   ✅ Notified admin $adminId about rejection');
      }
    } catch (e) {
      print('❌ Error notifying about rejected request: $e');
    }
  }

  Future<void> _addToRequestHistory({
    required String requestId,
    required String studentId,
    required String action,
    required String details,
    String? adminNote,
    required String adminId,
    required String adminEmail,
  }) async {
    await _firestore.collection('requestHistory').add({
      'requestId': requestId,
      'studentId': studentId,
      'action': action,
      'details': details,
      'adminNote': adminNote,
      'adminId': adminId,
      'adminEmail': adminEmail,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createNotification({
    required String recipientId,
    required String recipientType,
    required String requestId,
    String? oldStatus,
    String? newStatus,
    String? adminNote,
    String? notificationType,
    String? title,
    String? message,
  }) async {
    final notificationData = {
      'recipientId': recipientId,
      'recipientType': recipientType,
      'requestId': requestId,
      'type': notificationType ?? 'STATUS_UPDATE',
      'title': title ?? _getNotificationTitle(oldStatus ?? '', newStatus ?? ''),
      'message': message ??
          _getNotificationMessage(oldStatus ?? '', newStatus ?? '', adminNote),
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'data': {
        'oldStatus': oldStatus,
        'newStatus': newStatus,
        'adminNote': adminNote,
        'requestId': requestId,
      },
    };

    await _firestore.collection('notifications').add(notificationData);
  }

  String _getNotificationTitle(String oldStatus, String newStatus) {
    switch (newStatus) {
      case 'pending_student_affairs':
        return '⏳ Awaiting Student Affairs Review';
      case 'pending_warden':
        return '⏳ Awaiting Hall Warden Approval';
      case 'approved':
        return '🎉 Request Approved!';
      case 'rejected':
        return '❌ Request Declined';
      case 'completed':
        return '✅ Request Completed';
      default:
        return '📋 Request Status Updated';
    }
  }

  String _getNotificationMessage(
      String oldStatus, String newStatus, String? adminNote) {
    String baseMessage = '';

    switch (newStatus) {
      case 'pending_student_affairs':
        baseMessage =
            'Your request has been approved by HOD and is now awaiting Student Affairs review';
        break;
      case 'pending_warden':
        baseMessage =
            'Your request has been approved by Student Affairs and is now awaiting Hall Warden approval';
        break;
      case 'approved':
        baseMessage = 'Your exeat request has been fully approved!';
        break;
      case 'rejected':
        baseMessage = 'Your exeat request has been declined';
        break;
      default:
        baseMessage =
            'Your request status changed from ${oldStatus.replaceAll('_', ' ').toUpperCase()} to ${newStatus.replaceAll('_', ' ').toUpperCase()}';
    }

    if (adminNote != null && adminNote.isNotEmpty) {
      return '$baseMessage\nNote: $adminNote';
    }

    return baseMessage;
  }

  Future<void> addCommentToRequest({
    required String requestId,
    required String comment,
  }) async {
    try {
      isLoading.value = true;

      final user = _auth.currentUser;
      if (user == null) throw Exception('Admin not logged in');

      final requestRef = _firestore.collection('requests').doc(requestId);

      final commentData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': user.uid,
        'userEmail': user.email,
        'userName': user.displayName ?? 'Admin',
        'userRole': 'admin',
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await requestRef.collection('comments').add(commentData);
      await requestRef.update({'updatedAt': FieldValue.serverTimestamp()});

      final doc = await requestRef.get();
      final data = doc.data() ?? {};
      final studentId = data['studentId'] ?? '';

      await _createNotification(
        recipientId: studentId,
        recipientType: 'student',
        requestId: requestId,
        notificationType: 'NEW_COMMENT',
        title: 'New Comment on Your Request',
        message:
            'Admin: ${comment.length > 50 ? '${comment.substring(0, 50)}...' : comment}',
      );

      Get.snackbar('Success', 'Comment added successfully',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2));
    } catch (e) {
      Get.snackbar('Error', 'Failed to add comment: $e',
          snackPosition: SnackPosition.TOP);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  List<RequestModel> get filteredRequests {
    List<RequestModel> filtered = List.from(allRequests);

    if (selectedStatus.value != 'all') {
      filtered = filtered
          .where((request) => request.status == selectedStatus.value)
          .toList();
    }

    if (selectedPriority.value != 'all') {
      filtered = filtered
          .where((request) => request.priorityLevel == selectedPriority.value)
          .toList();
    }

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((request) {
        return request.studentName.toLowerCase().contains(query) ||
            request.studentMatric.toLowerCase().contains(query) ||
            request.destination.toLowerCase().contains(query) ||
            request.reason.toLowerCase().contains(query);
      }).toList();
    }

    filtered.sort((a, b) {
      int comparison = 0;
      switch (sortBy.value) {
        case 'priority':
          final priorityOrder = {
            'EMERGENCY': 0,
            'MEDICAL': 1,
            'FAMILY': 2,
            'NORMAL': 3
          };
          final aPriority = priorityOrder[a.priorityLevel] ?? 3;
          final bPriority = priorityOrder[b.priorityLevel] ?? 3;
          comparison = aPriority.compareTo(bPriority);
          break;
        case 'createdAt':
        default:
          comparison = b.createdAt.compareTo(a.createdAt);
          break;
      }
      return sortAscending.value ? comparison : -comparison;
    });

    return filtered;
  }

  void setStatusFilter(String status) => selectedStatus.value = status;
  void setPriorityFilter(String priority) => selectedPriority.value = priority;
  void setSearchQuery(String query) => searchQuery.value = query;
  void toggleSortOrder() => sortAscending.value = !sortAscending.value;
  void setSortBy(String field) => sortBy.value = field;
  void clearFilters() {
    selectedStatus.value = 'all';
    selectedPriority.value = 'all';
    searchQuery.value = '';
    sortBy.value = 'createdAt';
    sortAscending.value = false;
  }

  Future<void> refreshRequests() async {
    try {
      isLoading.value = true;
      _disposeStream();
      await initializeRequestStream();
      Get.snackbar('Success', 'Requests refreshed',
          duration: const Duration(seconds: 1));
    } catch (e) {
      Get.snackbar('Error', 'Failed to refresh requests: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Navigation helper methods
  void pushScreen(String screenName) {
    navigationStack.add(screenName);
    currentScreen.value = screenName;
    print('📱 Pushed screen: $screenName, Stack: $navigationStack');
  }

  void popScreen() {
    if (navigationStack.isNotEmpty) {
      navigationStack.removeLast();
      if (navigationStack.isNotEmpty) {
        currentScreen.value = navigationStack.last;
      }
    }
    print('📱 Popped screen, Stack: $navigationStack');
  }

  // Clean reset for navigation
  void resetNavigation() {
    navigationStack.clear();
    currentScreen.value = '';
    print('📱 Navigation reset');
  }

  // Force refresh without stream reinitialization
  Future<void> softRefresh() async {
    try {
      isLoading.value = true;

      // Just refresh the data without restarting stream
      if (_allRequestsStream != null && !_allRequestsStream!.isPaused) {
        // The stream will automatically update
        // We just need to trigger UI refresh
        update();
      }

      await Future.delayed(const Duration(milliseconds: 300));
      Get.snackbar('Refreshed', 'Data updated',
          duration: const Duration(seconds: 1));
    } catch (e) {
      print('Error in softRefresh: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Check if stream is active
  bool get isStreamActive => _allRequestsStream != null;

  // Debug method to check database statuses
  Future<void> debugCheckDatabase() async {
    try {
      print('🔍 DEBUG: Checking all requests in database...');
      final allRequestsSnapshot = await _firestore.collection('requests').get();

      print(
          '   Total requests in database: ${allRequestsSnapshot.docs.length}');
      print('   Request status breakdown:');

      final statusCount = <String, int>{};
      for (final doc in allRequestsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'unknown';
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }

      for (final entry in statusCount.entries) {
        print('   ${entry.key}: ${entry.value}');
      }
    } catch (e) {
      print('❌ DEBUG: Error checking database: $e');
    }
  }

  // Debug method for HOD → Student Affairs flow
  Future<void> debugStatusFlow() async {
    try {
      print('🔍 DEBUG: Checking HOD → Student Affairs flow...');

      // Check all pending_hod requests
      final hodPendingQuery = await _firestore
          .collection('requests')
          .where('status', isEqualTo: 'pending_hod')
          .get();

      print('   Found ${hodPendingQuery.docs.length} requests in pending_hod');

      // Check all pending_student_affairs requests
      final studentAffairsQuery = await _firestore
          .collection('requests')
          .where('status', isEqualTo: 'pending_student_affairs')
          .get();

      print(
          '   Found ${studentAffairsQuery.docs.length} requests in pending_student_affairs');
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  // DEBUG: Method to check admin role
  Future<void> debugAdminRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    print('🔍 DEBUG: Checking admin role for user ${user.uid}');

    try {
      final adminDoc =
          await _firestore.collection('admins').doc(user.uid).get();

      if (!adminDoc.exists) {
        print('❌ Admin document not found for user ${user.uid}');
        print(
            '   Check Firestore: collection "admins" -> document "${user.uid}"');
        return;
      }

      final data = adminDoc.data()!;
      print('📋 Admin Document Data:');
      print('   ID: ${user.uid}');
      print('   Email: ${user.email}');
      print('   Role: ${data['role']}');
      print(
          '   Normalized Role: ${_normalizeRole(data['role']?.toString() ?? '')}');
      print('   Hall ID: ${data['hallId']}');
      print('   Department ID: ${data['departmentId']}');
      print('   Name: ${data['name']}');
      print('   Email (from DB): ${data['email']}');

      // Check if role contains "student affairs"
      final role = data['role']?.toString() ?? '';
      final lowerRole = role.toLowerCase();
      if (lowerRole.contains('student') && lowerRole.contains('affairs')) {
        print('✅ Role IS recognized as Student Affairs!');
      } else {
        print('❌ Role is NOT recognized as Student Affairs');
        print(
            '   Try: "Student Affairs", "student_affairs", "student affairs"');
      }
    } catch (e) {
      print('❌ Error checking admin role: $e');
    }
  }
}
