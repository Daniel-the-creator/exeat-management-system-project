// controllers/admin_notification_controller.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminNotificationController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Observable notifications
  var notifications = <Map<String, dynamic>>[].obs;
  var unreadCount = 0.obs;

  // Admin info
  final RxString _adminRole = ''.obs;
  final RxString _adminHallId = ''.obs;
  final RxString _adminDepartmentId = ''.obs;

  StreamSubscription<QuerySnapshot>? _notificationStream;

  @override
  void onInit() {
    super.onInit();
    print('👑 AdminNotificationController initialized');
    initializeAdminNotifications();
  }

  @override
  void onClose() {
    _notificationStream?.cancel();
    super.onClose();
  }

  Future<void> initializeAdminNotifications() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('❌ No admin user logged in');
      return;
    }

    print('🔵 Initializing ADMIN notifications for user: $userId');

    try {
      // Get admin info first
      await _loadAdminInfo(userId);

      // Setup notification stream based on admin role
      _setupNotificationStream();
    } catch (e) {
      print('❌ Error initializing admin notifications: $e');
    }
  }

  Future<void> _loadAdminInfo(String adminId) async {
    try {
      final adminDoc = await _firestore.collection('admins').doc(adminId).get();

      if (!adminDoc.exists) {
        throw Exception('Admin document not found');
      }

      final data = adminDoc.data()!;
      _adminRole.value = data['role']?.toString() ?? '';
      _adminHallId.value = data['hallId']?.toString() ?? '';
      _adminDepartmentId.value = data['departmentId']?.toString() ?? '';

      print('📋 Admin Info:');
      print('   Role: ${_adminRole.value}');
      print('   Hall ID: ${_adminHallId.value}');
      print('   Department ID: ${_adminDepartmentId.value}');
    } catch (e) {
      print('❌ Error loading admin info: $e');
      rethrow;
    }
  }

  void _setupNotificationStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    print('📡 Setting up ADMIN notification stream for user: $userId');

    // Cancel existing stream if any
    _notificationStream?.cancel();

    // FIX: Filter for admin notifications specifically
    Query query = _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('recipientType', isEqualTo: 'admin'); // Added this filter

    print('🔍 Query: recipientId == $userId AND recipientType == "admin"');

    _notificationStream = query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _processAdminNotifications(snapshot);
    }, onError: (error) {
      print('❌ Error in ADMIN notification stream: $error');
      // If there's an index error, show the link
      if (error.toString().contains('index')) {
        print(
            '⚠️ Create this composite index: recipientId (Ascending), recipientType (Ascending), createdAt (Descending)');
        print(
            '   OR you can create: recipientId (Ascending), createdAt (Descending)');
        print('   (The second index will work but may be less efficient)');
      }
    });
  }

  void _processAdminNotifications(QuerySnapshot snapshot) {
    print('✅ Received ${snapshot.docs.length} ADMIN notifications');

    // Debug: Show all document data
    if (snapshot.docs.isNotEmpty) {
      print('📋 Raw notification data:');
      snapshot.docs.take(3).forEach((doc) {
        print('   ID: ${doc.id}');
        print('   Data: ${doc.data()}');
      });
    }

    notifications.value = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        ...data,
        'createdAt': data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      };
    }).toList();

    // Update unread count
    unreadCount.value = notifications
        .where((n) => n['isRead'] == false || n['isRead'] == null)
        .length;

    print(
        '📊 Total ADMIN notifications: ${notifications.length}, Unread: ${unreadCount.value}');

    // Log all notifications for debugging
    if (notifications.isNotEmpty) {
      print('📋 All notifications:');
      for (var notification in notifications) {
        print('   - ID: ${notification['id']}');
        print('   - Title: ${notification['title']}');
        print('   - RecipientId: ${notification['recipientId']}');
        print('   - RecipientType: ${notification['recipientType']}');
        print('   - Type: ${notification['type']}');
        print('   - isRead: ${notification['isRead']}');
        print('   ---');
      }
    } else {
      print('⚠️ No notifications found for this admin');

      // Debug: Check what notifications exist for this user
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        _debugCheckAllNotifications(userId);
      }
    }
  }

  // Debug method to check all notifications
  Future<void> _debugCheckAllNotifications(String userId) async {
    try {
      print('🔍 DEBUG: Checking all notifications for user $userId...');

      // Check notifications with recipientId only (old format)
      final oldFormatQuery = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .get();

      print(
          '   Found ${oldFormatQuery.docs.length} notifications with recipientId=$userId');

      if (oldFormatQuery.docs.isNotEmpty) {
        print('   📋 Notifications found (without recipientType filter):');
        for (var doc in oldFormatQuery.docs) {
          final data = doc.data();
          print('      - ID: ${doc.id}');
          print('      - Title: ${data['title']}');
          print('      - RecipientType: ${data['recipientType']}');
          print('      - Type: ${data['type']}');
          print('      ---');
        }
      }

      // Check all notifications in the system
      final allNotifications =
          await _firestore.collection('notifications').limit(10).get();

      print('   🔍 First 10 notifications in the system:');
      for (var doc in allNotifications.docs) {
        final data = doc.data();
        print('      - ID: ${doc.id}');
        print('      - Title: ${data['title']}');
        print('      - RecipientId: ${data['recipientId']}');
        print('      - RecipientType: ${data['recipientType']}');
        print('      ---');
      }
    } catch (e) {
      print('❌ Error in debug check: $e');
    }
  }

  // ADD THIS METHOD for manual loading if needed
  Future<void> loadNotifications() async {
    print('🔄 Manually loading notifications');
    // Re-initialize the stream
    _notificationStream?.cancel();
    await initializeAdminNotifications();
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      print('✅ ADMIN Notification marked as read: $notificationId');

      // Update local state
      final index = notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        notifications[index]['isRead'] = true;
        notifications.refresh();
        unreadCount.value--;
      }
    } catch (e) {
      print('❌ Error marking ADMIN notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get all unread notifications for this user (with recipientType filter)
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('recipientType', isEqualTo: 'admin')
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadNotifications.docs.isEmpty) {
        print('📭 No unread ADMIN notifications to mark');
        return;
      }

      final batch = _firestore.batch();

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ All ADMIN notifications marked as read');

      // Update local state
      for (var notification in notifications) {
        notification['isRead'] = true;
      }
      notifications.refresh();
      unreadCount.value = 0;

      Get.snackbar(
        'Success',
        'All notifications marked as read',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      print('❌ Error marking all ADMIN notifications as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      print('✅ ADMIN Notification deleted: $notificationId');

      // Remove from local list
      notifications.removeWhere((n) => n['id'] == notificationId);
      notifications.refresh();

      // Update unread count if it was unread
      unreadCount.value =
          notifications.where((n) => n['isRead'] == false).length;
    } catch (e) {
      print('❌ Error deleting ADMIN notification: $e');
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get all notifications for this user (with recipientType filter)
      final userNotifications = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('recipientType', isEqualTo: 'admin')
          .get();

      if (userNotifications.docs.isEmpty) {
        print('📭 No ADMIN notifications to clear');
        return;
      }

      final batch = _firestore.batch();
      for (var doc in userNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Clear local list
      notifications.clear();
      unreadCount.value = 0;

      Get.snackbar(
        'Success',
        'All notifications cleared',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      print('❌ Error clearing ADMIN notifications: $e');
    }
  }

  // Get filtered notifications
  List<Map<String, dynamic>> getFilteredNotifications(String filter) {
    if (filter == 'all') {
      return notifications;
    } else if (filter == 'unread') {
      return notifications
          .where((n) => n['isRead'] == false || n['isRead'] == null)
          .toList();
    } else {
      return notifications.where((n) => n['type'] == filter).toList();
    }
  }

  // Get notification statistics
  Map<String, int> getNotificationStats() {
    return {
      'total': notifications.length,
      'unread': notifications
          .where((n) => n['isRead'] == false || n['isRead'] == null)
          .length,
      'new_requests':
          notifications.where((n) => n['type'] == 'NEW_REQUEST').length,
      'urgent': notifications.where((n) => _isUrgentNotification(n)).length,
    };
  }

  bool _isUrgentNotification(Map<String, dynamic> notification) {
    final priority = notification['priorityLevel']?.toString() ??
        notification['data']?['priorityLevel']?.toString() ??
        '';
    final type = notification['type']?.toString() ?? '';

    return priority == 'EMERGENCY' ||
        priority == 'MEDICAL' ||
        type == 'NEW_REQUEST';
  }

  // Get urgent notifications
  List<Map<String, dynamic>> getUrgentNotifications() {
    return notifications.where((n) => _isUrgentNotification(n)).toList();
  }

  // Format notification time
  String formatNotificationTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Get notification icon based on type
  IconData getNotificationIcon(String type) {
    switch (type) {
      case 'NEW_REQUEST':
        return Icons.email;
      case 'URGENT':
        return Icons.warning;
      case 'SYSTEM':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  // Get notification color based on type
  Color getNotificationColor(String type) {
    switch (type) {
      case 'NEW_REQUEST':
        return Colors.orange;
      case 'URGENT':
        return Colors.red;
      case 'SYSTEM':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  // Refresh notifications
  Future<void> refreshNotifications() async {
    print('🔄 Refreshing ADMIN notifications');
    _notificationStream?.cancel();
    await initializeAdminNotifications();
  }

  // Get admin role for display
  String get adminRoleDisplay {
    final role = _adminRole.value.toLowerCase();
    if (role.contains('student affairs')) return 'Student Affairs';
    if (role.contains('super admin')) return 'Super Admin';
    if (_adminHallId.value.isNotEmpty) return 'Hall Warden';
    if (_adminDepartmentId.value.isNotEmpty) return 'Department Head';
    return 'Administrator';
  }

  // Helper method to check if notifications are being filtered correctly
  void debugNotificationStatus() {
    print('🔍 DEBUG: Notification Status');
    print('   User ID: ${_auth.currentUser?.uid}');
    print('   Admin Role: ${_adminRole.value}');
    print('   Total notifications: ${notifications.length}');
    print('   Unread count: ${unreadCount.value}');
    print('   Stream active: ${_notificationStream != null}');
  }
}
