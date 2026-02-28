// services/exeat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:exeat_system/model/request_model.dart';

class ExeatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===================== CREATE REQUEST (Student) =====================
  Future<RequestModel> createRequest({
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
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get student data
      final studentDoc =
          await _firestore.collection('students').doc(user.uid).get();
      if (!studentDoc.exists) throw Exception('Student not found');

      final studentData = studentDoc.data()!;
      final now = Timestamp.now();

      // Extract hall and department IDs
      final hallId = studentData['hallId'] as String?;
      final departmentId = studentData['departmentId'] as String?;

      print('🎓 Student Hall ID: $hallId');
      print('🎓 Student Department ID: $departmentId');

      // Create new document reference
      final requestRef = _firestore.collection('requests').doc();
      final requestId = requestRef.id;

      // STEP 1: Always start with HOD approval
      String initialStatus = 'pending_hod';

      // Create RequestModel with hall and department IDs
      final request = RequestModel(
        requestId: requestId,
        studentId: user.uid,
        studentName: studentData['name'] ?? studentData['fullName'] ?? '',
        studentEmail: studentData['email'] ?? '',
        studentMatric:
            studentData['matricNumber'] ?? studentData['matricNo'] ?? '',
        studentPhone: phone,
        destination: destination,
        leaveDate: leaveDate,
        leaveTime: leaveTime,
        returnDate: returnDate,
        returnTime: returnTime,
        reason: reason,
        contactPerson: contactPerson,
        contactNumber: contactNumber,
        guardianApproval: guardianApproval,
        priorityLevel: priorityLevel,
        status: initialStatus,
        createdAt: now,
        updatedAt: now,
        hallId: hallId,
        departmentId: departmentId,
      );

      // Save to Firestore
      await requestRef.set(request.toMap());

      print('✅ Request created with status: $initialStatus');
      print('   Hall ID: $hallId, Department ID: $departmentId');

      // STEP 2: Notify HOD only (first level of approval)
      await _createAdminNotification(
        studentName: request.studentName,
        studentMatric: request.studentMatric,
        requestId: requestId,
        priorityLevel: priorityLevel,
        destination: destination,
        studentHallId: hallId,
        studentDepartmentId: departmentId,
        targetRole: 'hod',
      );

      // Notify student
      await _createStudentNotification(
        studentId: user.uid,
        type: 'REQUEST_SUBMITTED',
        title: 'Request Submitted Successfully',
        message:
            'Your exeat request has been submitted and is awaiting HOD approval (Step 1 of 3)',
        requestId: requestId,
      );

      return request;
    } catch (e) {
      throw Exception('Failed to create request: $e');
    }
  }

  // ===================== UPDATE REQUEST STATUS (Admin) =====================
  Future<void> updateRequestStatus({
    required String requestId,
    required String newStatus,
    required String adminNote,
    required String adminId,
    required String adminEmail,
  }) async {
    try {
      final requestRef = _firestore.collection('requests').doc(requestId);

      await _firestore.runTransaction((transaction) async {
        final requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) throw Exception('Request not found');

        final requestData = requestDoc.data()!;
        final oldStatus = requestData['status'] ?? 'pending_hod';
        final studentId = requestData['studentId'] ?? '';
        final hallId = requestData['hallId'] as String?;
        final departmentId = requestData['departmentId'] as String?;
        final now = Timestamp.now();

        // Determine next status based on current status and approval workflow
        // WORKFLOW: HOD → Student Affairs → Warden → Approved
        String finalStatus = newStatus;
        String? nextNotificationRole;
        String updatedAdminNote = adminNote;

        if (newStatus == 'approved') {
          // Determine which step we're in
          if (oldStatus == 'pending_hod') {
            // STEP 1 COMPLETE: HOD approved, move to Student Affairs
            finalStatus = 'pending_student_affairs';
            nextNotificationRole = 'student_affairs';
            updatedAdminNote =
                'Approved by HOD - Awaiting Student Affairs review (Step 2 of 3)';
            print('📋 HOD approved → Moving to Student Affairs');
          } else if (oldStatus == 'pending_student_affairs') {
            // STEP 2 COMPLETE: Student Affairs approved, move to Warden
            finalStatus = 'pending_warden';
            nextNotificationRole = 'warden';
            updatedAdminNote =
                'Approved by Student Affairs - Awaiting Hall Warden approval (Step 3 of 3)';
            print('📋 Student Affairs approved → Moving to Warden');
          } else if (oldStatus == 'pending_warden') {
            // STEP 3 COMPLETE: Warden approved, fully approved
            finalStatus = 'approved';
            updatedAdminNote =
                'Fully approved by Hall Warden - All approvals complete';
            print('📋 Warden approved → FULLY APPROVED');
          }
        } else if (newStatus == 'rejected') {
          // Any level can reject
          finalStatus = 'rejected';
          updatedAdminNote =
              adminNote.isNotEmpty ? adminNote : 'Request declined';
          print('📋 Request rejected at $oldStatus stage');
        }

        // Update request
        transaction.update(requestRef, {
          'status': finalStatus,
          'adminNote': updatedAdminNote,
          'processedBy': adminEmail,
          'processedAt': now,
          'updatedAt': now,
        });

        print('✅ Status updated: $oldStatus → $finalStatus');

        // Add to request history
        await _addToRequestHistory(
          requestId: requestId,
          studentId: studentId,
          action: 'STATUS_UPDATE',
          details: 'Changed from $oldStatus to $finalStatus by $adminEmail',
          adminNote: updatedAdminNote,
          adminId: adminId,
          adminEmail: adminEmail,
        );

        // Notify student
        await _createStudentNotification(
          studentId: studentId,
          type: 'STATUS_UPDATE',
          title: _getNotificationTitle(finalStatus),
          message:
              _getNotificationMessage(oldStatus, finalStatus, updatedAdminNote),
          requestId: requestId,
          data: {
            'oldStatus': oldStatus,
            'newStatus': finalStatus,
            'adminNote': updatedAdminNote,
          },
        );

        // If moving to next approval level, notify next admin
        if (nextNotificationRole != null) {
          print('📨 Notifying next approval level: $nextNotificationRole');
          await _createAdminNotification(
            studentName: requestData['studentName'] ?? '',
            studentMatric: requestData['studentMatric'] ?? '',
            requestId: requestId,
            priorityLevel: requestData['priorityLevel'] ?? 'NORMAL',
            destination: requestData['destination'] ?? '',
            studentHallId: hallId,
            studentDepartmentId: departmentId,
            targetRole: nextNotificationRole,
          );
        }
      });
    } catch (e) {
      throw Exception('Failed to update request status: $e');
    }
  }

  // ===================== NOTIFICATION HELPERS =====================
  Future<void> _createAdminNotification({
    required String studentName,
    required String studentMatric,
    required String requestId,
    required String priorityLevel,
    required String destination,
    String? studentHallId,
    String? studentDepartmentId,
    String? targetRole, // 'hod', 'student_affairs', 'warden', or null for all
  }) async {
    try {
      // Get all admins
      final adminsSnapshot = await _firestore.collection('admins').get();

      print('📨 Creating notifications for role: ${targetRole ?? "all"}');
      int notificationsSent = 0;

      for (final adminDoc in adminsSnapshot.docs) {
        final adminId = adminDoc.id;
        final adminData = adminDoc.data();
        final adminRole = (adminData['role'] as String? ?? '').toLowerCase();
        final normalizedAdminRole = _normalizeRole(adminRole);
        final adminHallId = adminData['hallId'] as String?;
        final adminDepartmentId = adminData['departmentId'] as String?;

        bool shouldNotify = false;

        // If targeting specific role
        if (targetRole != null) {
          final normalizedTarget = _normalizeRole(targetRole);

          if (normalizedTarget == 'hod') {
            // HOD must match department
            shouldNotify = (normalizedAdminRole == 'hod' ||
                    normalizedAdminRole == 'super_admin') &&
                adminDepartmentId != null &&
                adminDepartmentId.isNotEmpty &&
                adminDepartmentId == studentDepartmentId;
            print(
                '   Checking admin ${adminData['email']}: role=$adminRole, normalized=$normalizedAdminRole, target=$normalizedTarget, match=$shouldNotify');
          } else if (normalizedTarget == 'student_affairs') {
            // Student Affairs - match by role
            shouldNotify = normalizedAdminRole == 'student_affairs' ||
                normalizedAdminRole == 'super_admin';
            print(
                '   Checking admin ${adminData['email']}: role=$adminRole, normalized=$normalizedAdminRole, target=$normalizedTarget, match=$shouldNotify');
          } else if (normalizedTarget == 'warden') {
            // Warden must match hall
            shouldNotify = (normalizedAdminRole == 'warden' ||
                    normalizedAdminRole == 'super_admin') &&
                adminHallId != null &&
                adminHallId.isNotEmpty &&
                adminHallId == studentHallId;
            print(
                '   Checking admin ${adminData['email']}: role=$adminRole, normalized=$normalizedAdminRole, target=$normalizedTarget, match=$shouldNotify');
          }
        } else {
          // General notification (broadcast to all relevant admins)
          if (normalizedAdminRole == 'student_affairs' ||
              normalizedAdminRole == 'super_admin') {
            shouldNotify = true;
          } else if (normalizedAdminRole == 'warden') {
            shouldNotify = adminHallId != null &&
                adminHallId.isNotEmpty &&
                adminHallId == studentHallId;
          } else if (normalizedAdminRole == 'hod') {
            shouldNotify = adminDepartmentId != null &&
                adminDepartmentId.isNotEmpty &&
                adminDepartmentId == studentDepartmentId;
          }

          print(
              '   Checking admin ${adminData['email']}: role=$adminRole, normalized=$normalizedAdminRole, match=$shouldNotify');
        }

        // Send notification only to relevant admins
        if (shouldNotify) {
          await _firestore.collection('notifications').add({
            'recipientId': adminId,
            'recipientType': 'admin',
            'type': 'NEW_REQUEST',
            'title': 'New Exeat Request Awaiting Your Approval',
            'message':
                '$studentName ($studentMatric) - $priorityLevel priority request to $destination',
            'requestId': requestId,
            'data': {
              'studentName': studentName,
              'studentMatric': studentMatric,
              'priorityLevel': priorityLevel,
              'destination': destination,
              'requestId': requestId,
            },
            'isRead': false,
            'createdAt': Timestamp.now(),
          });
          notificationsSent++;
          print(
              '   ✅ Sent notification to ${adminData['email']} (Role: $adminRole, Normalized: $normalizedAdminRole)');
        }
      }

      print(
          '📨 Total notifications sent: $notificationsSent for role: ${targetRole ?? "all"}');
    } catch (e) {
      print('❌ Error creating admin notification: $e');
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
    if (lowerRole.contains('warden')) {
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

  Future<void> _createStudentNotification({
    required String studentId,
    required String type,
    required String title,
    required String message,
    required String requestId,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'recipientId': studentId,
        'recipientType': 'student',
        'type': type,
        'title': title,
        'message': message,
        'requestId': requestId,
        'data': data ?? {'requestId': requestId},
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
      print('📨 Created STUDENT notification for: $studentId');
    } catch (e) {
      print('❌ Error creating student notification: $e');
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
    try {
      await _firestore.collection('requestHistory').add({
        'requestId': requestId,
        'studentId': studentId,
        'action': action,
        'details': details,
        'adminNote': adminNote,
        'adminId': adminId,
        'adminEmail': adminEmail,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      print('❌ Error adding to request history: $e');
    }
  }

  String _getNotificationTitle(String newStatus) {
    switch (newStatus) {
      case 'pending_hod':
        return '📝 Request Submitted';
      case 'pending_student_affairs':
        return '⏳ Awaiting Student Affairs Review (Step 2/3)';
      case 'pending_warden':
        return '⏳ Awaiting Hall Warden Approval (Step 3/3)';
      case 'approved':
        return '🎉 Request Fully Approved!';
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
      case 'pending_hod':
        baseMessage = 'Your request is awaiting HOD approval (Step 1 of 3)';
        break;
      case 'pending_student_affairs':
        baseMessage =
            'HOD approved! Your request is now awaiting Student Affairs review (Step 2 of 3)';
        break;
      case 'pending_warden':
        baseMessage =
            'Student Affairs approved! Your request is now awaiting Hall Warden approval (Step 3 of 3)';
        break;
      case 'approved':
        baseMessage =
            'Congratulations! Your exeat request has been fully approved by all authorities!';
        break;
      case 'rejected':
        baseMessage = 'Your exeat request has been declined';
        break;
      default:
        baseMessage =
            'Your request status changed from ${oldStatus.replaceAll('_', ' ').toUpperCase()} to ${newStatus.replaceAll('_', ' ').toUpperCase()}';
    }

    if (adminNote != null && adminNote.isNotEmpty) {
      return '$baseMessage\n\nNote: $adminNote';
    }

    return baseMessage;
  }

  // ===================== ADD COMMENT TO REQUEST =====================
  Future<void> addCommentToRequest({
    required String requestId,
    required String comment,
    required String userId,
    required String userName,
    required String userRole,
  }) async {
    try {
      final requestRef = _firestore.collection('requests').doc(requestId);

      final commentData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'comment': comment,
        'timestamp': Timestamp.now(),
      };

      await requestRef.collection('comments').add(commentData);
      await requestRef.update({'updatedAt': Timestamp.now()});

      final requestDoc = await requestRef.get();
      final studentId = requestDoc['studentId'] ?? '';

      if (userRole == 'admin') {
        await _createStudentNotification(
          studentId: studentId,
          type: 'NEW_COMMENT',
          title: 'New Comment on Your Request',
          message: 'An admin added a comment to your request',
          requestId: requestId,
          data: {'comment': comment, 'requestId': requestId},
        );
      }
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  // ===================== GET REQUESTS =====================
  Stream<List<RequestModel>> getStudentRequests(String studentId) {
    return _firestore
        .collection('requests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<RequestModel>> getAllRequests() {
    return _firestore
        .collection('requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<RequestModel>> getPendingRequests() {
    return _firestore
        .collection('requests')
        .where('status', whereIn: [
          'pending_hod',
          'pending_student_affairs',
          'pending_warden'
        ])
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ===================== CANCEL REQUEST (Student) =====================
  Future<void> cancelRequest({
    required String requestId,
    required String studentId,
  }) async {
    try {
      final requestRef = _firestore.collection('requests').doc(requestId);
      final requestDoc = await requestRef.get();

      if (!requestDoc.exists) throw Exception('Request not found');

      final data = requestDoc.data()!;
      if (data['studentId'] != studentId) {
        throw Exception('Not authorized to cancel this request');
      }

      if (!data['status'].toString().startsWith('pending')) {
        throw Exception('Only pending requests can be cancelled');
      }

      await requestRef.update({
        'status': 'cancelled',
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to cancel request: $e');
    }
  }

  // ===================== ADDITIONAL HELPER METHODS =====================

  // Check if user has any pending requests
  Future<bool> hasPendingRequests(String studentId) async {
    try {
      final querySnapshot = await _firestore
          .collection('requests')
          .where('studentId', isEqualTo: studentId)
          .where('status', whereIn: [
            'pending_hod',
            'pending_student_affairs',
            'pending_warden'
          ])
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking pending requests: $e');
      return false;
    }
  }

  // Get request by ID
  Future<RequestModel?> getRequestById(String requestId) async {
    try {
      final doc = await _firestore.collection('requests').doc(requestId).get();
      if (doc.exists) {
        return RequestModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('❌ Error getting request by ID: $e');
      return null;
    }
  }

  // Get comments for a request
  Stream<List<Map<String, dynamic>>> getRequestComments(String requestId) {
    return _firestore
        .collection('requests')
        .doc(requestId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Get requests by status (for admin filtering)
  Stream<List<RequestModel>> getRequestsByStatus(String status) {
    return _firestore
        .collection('requests')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get requests for specific admin role
  Stream<List<RequestModel>> getRequestsForAdminRole({
    required String role,
    String? departmentId,
    String? hallId,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('requests');

    final normalizedRole = _normalizeRole(role);

    if (normalizedRole == 'hod' && departmentId != null) {
      query = query
          .where('departmentId', isEqualTo: departmentId)
          .where('status', whereIn: [
        'pending_hod',
        'pending_student_affairs',
        'pending_warden',
        'approved',
        'rejected'
      ]);
    } else if (normalizedRole == 'student_affairs') {
      // Student Affairs sees all requests
      query = query.orderBy('createdAt', descending: true);
    } else if (normalizedRole == 'warden' && hallId != null) {
      query = query
          .where('hallId', isEqualTo: hallId)
          .where('status', whereIn: ['pending_warden', 'approved', 'rejected']);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
        .toList());
  }
}
