import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class ExpirationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _timer;

  Future<void> checkAndDeleteExpiredRequests() async {
    if (kDebugMode) {
      print('🚀 Checking for requests to delete (older than 3 days)...');
    }

    final now = DateTime.now();
    final threeDaysAgo = now.subtract(const Duration(days: 3));

    try {
      // Find requests that are pending at any level and created more than 3 days ago
      final oldPendingRequests = await _firestore
          .collection('requests')
          .where('status', whereIn: [
            'pending_hod',
            'pending_student_affairs',
            'pending_warden',
            'pending'
          ])
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(threeDaysAgo))
          .get();

      if (oldPendingRequests.docs.isEmpty) {
        if (kDebugMode) {
          print('✅ No old pending requests found for deletion');
        }
        return;
      }

      if (kDebugMode) {
        print('🗑️ Found ${oldPendingRequests.docs.length} requests to delete');
      }

      WriteBatch batch = _firestore.batch();

      for (var doc in oldPendingRequests.docs) {
        final data = doc.data();

        // 1. Delete the request document
        batch.delete(doc.reference);

        // 2. Create a notification for the student (optional but helpful)
        // Note: recipientId is studentId
        final studentId = data['studentId'];
        if (studentId != null) {
          batch.set(
            _firestore.collection('notifications').doc(),
            {
              'recipientId': studentId,
              'recipientRole': 'STUDENT',
              'type': 'REQUEST_DELETED_AUTO',
              'title': 'Request Auto-Deleted',
              'message':
                  'Your exeat request was deleted after 3 days without approval.',
              'requestId': doc.id,
              'isRead': false,
              'createdAt': Timestamp.now(),
            },
          );
        }
      }

      await batch.commit();

      if (kDebugMode) {
        print(
            '✅ Successfully deleted ${oldPendingRequests.docs.length} old requests');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error auto-deleting old requests: $e');
      }
    }
  }

  void startExpirationChecker() {
    // Run every hour when app is open
    _timer = Timer.periodic(const Duration(hours: 1), (timer) async {
      await checkAndDeleteExpiredRequests();
    });

    // Also check immediately on startup
    checkAndDeleteExpiredRequests();
  }

  void stopExpirationChecker() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopExpirationChecker();
  }
}
