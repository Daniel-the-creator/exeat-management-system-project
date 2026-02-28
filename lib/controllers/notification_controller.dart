import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class StudentNotificationController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Observable notifications
  var notifications = <Map<String, dynamic>>[].obs;
  var unreadCount = 0.obs;

  // Track stream state
  StreamSubscription<QuerySnapshot>? _notificationStream;
  final RxBool _isListening = false.obs;
  bool get isListening => _isListening.value;

  @override
  void onInit() {
    super.onInit();
    print('🎓 StudentNotificationController initialized');
    // Don't auto-initialize - wait for explicit call from InitializationService
  }

  @override
  void onClose() {
    _notificationStream?.cancel();
    _isListening.value = false;
    super.onClose();
  }

  // This is the main method - called from InitializationService
  void startListening() {
    if (_isListening.value) {
      print('✅ Notification stream already listening');
      return;
    }

    initializeNotifications();
  }

  void initializeNotifications() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('❌ No student user logged in');
      return;
    }

    print('🔵 Loading STUDENT notifications for user: $userId');

    // Cancel existing stream if any
    _notificationStream?.cancel();

    _notificationStream = _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('recipientType', isEqualTo: 'student')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _processNotifications(snapshot);
      _isListening.value = true;
    }, onError: (error) {
      print('❌ Error loading student notifications: $error');
      _isListening.value = false;

      // Show index creation link if needed
      if (error.toString().contains('index')) {
        print(
            '⚠️ Create this composite index: recipientId (Ascending), recipientType (Ascending), createdAt (Descending)');
      }

      // Retry after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (_auth.currentUser != null) {
          print('🔄 Retrying notification stream...');
          _notificationStream?.cancel();
          initializeNotifications();
        }
      });
    });
  }

  void _processNotifications(QuerySnapshot snapshot) {
    print('✅ Received ${snapshot.docs.length} STUDENT notifications');

    // Debug: Show first few documents
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

    // Update unread count (treat null as unread)
    unreadCount.value = notifications
        .where((n) => n['isRead'] == false || n['isRead'] == null)
        .length;

    print(
        '📊 Total STUDENT notifications: ${notifications.length}, Unread: ${unreadCount.value}');

    // Log all notifications for debugging
    if (notifications.isNotEmpty) {
      print('📋 All student notifications:');
      for (var notification in notifications) {
        print('   - ID: ${notification['id']}');
        print('   - Title: ${notification['title']}');
        print('   - RecipientId: ${notification['recipientId']}');
        print('   - isRead: ${notification['isRead']}');
        print('   ---');
      }
    } else {
      print('⚠️ No notifications found for this student');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      print('✅ STUDENT Notification marked as read: $notificationId');

      // Update local state
      final index = notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        notifications[index]['isRead'] = true;
        notifications.refresh();
        unreadCount.value--;
      }
    } catch (e) {
      print('❌ Error marking STUDENT notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('recipientType', isEqualTo: 'student')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ All STUDENT notifications marked as read');

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
      print('❌ Error marking all STUDENT notifications as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      print('✅ STUDENT Notification deleted: $notificationId');

      // Remove from local list
      notifications.removeWhere((n) => n['id'] == notificationId);
      notifications.refresh();

      // Update unread count if it was unread
      unreadCount.value = notifications
          .where((n) => n['isRead'] == false || n['isRead'] == null)
          .length;
    } catch (e) {
      print('❌ Error deleting STUDENT notification: $e');
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userNotifications = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('recipientType', isEqualTo: 'student')
          .get();

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
      print('❌ Error clearing STUDENT notifications: $e');
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

  // Get notification types count
  Map<String, int> getNotificationStats() {
    return {
      'total': notifications.length,
      'unread': notifications
          .where((n) => n['isRead'] == false || n['isRead'] == null)
          .length,
      'status_updates':
          notifications.where((n) => n['type'] == 'STATUS_UPDATE').length,
      'comments': notifications.where((n) => n['type'] == 'NEW_COMMENT').length,
    };
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
      case 'STATUS_UPDATE':
        return Icons.update;
      case 'NEW_COMMENT':
        return Icons.comment;
      case 'SYSTEM':
        return Icons.settings;
      case 'NEW_REQUEST':
        return Icons.email;
      default:
        return Icons.notifications;
    }
  }

  // Get notification color based on type
  Color getNotificationColor(String type) {
    switch (type) {
      case 'STATUS_UPDATE':
        return Colors.blue;
      case 'NEW_COMMENT':
        return Colors.purple;
      case 'SYSTEM':
        return Colors.grey;
      case 'NEW_REQUEST':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  // Refresh notifications
  Future<void> refreshNotifications() async {
    print('🔄 Refreshing STUDENT notifications');
    _notificationStream?.cancel();
    _isListening.value = false;
    initializeNotifications();
  }

  // Check if notification is urgent
  bool isUrgentNotification(Map<String, dynamic> notification) {
    final type = notification['type']?.toString() ?? '';
    final title = notification['title']?.toString() ?? '';
    final priority = notification['priorityLevel']?.toString() ??
        notification['data']?['priorityLevel']?.toString() ??
        '';

    return type == 'STATUS_UPDATE' ||
        title.toLowerCase().contains('emergency') ||
        priority == 'EMERGENCY';
  }

  // Get urgent notifications
  List<Map<String, dynamic>> getUrgentNotifications() {
    return notifications.where((n) => isUrgentNotification(n)).toList();
  }

  // Stop listening (called on logout)
  void stopListening() {
    print('🛑 Stopping notification listener');
    _notificationStream?.cancel();
    _isListening.value = false;
    notifications.clear();
    unreadCount.value = 0;
  }
}
