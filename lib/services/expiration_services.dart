import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class ExpirationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _timer;

  Future<void> checkAndExpireRequests() async {
    if (kDebugMode) {
      print('Checking for expired requests...');
    }

    final now = DateTime.now();
    final threeDaysAgo = now.subtract(const Duration(days: 3));

    try {
      final expiredRequests = await _firestore
          .collection('exeatRequests')
          .where('status',
              whereIn: ['PENDING_HOD', 'PENDING_SA', 'PENDING_WARDEN'])
          .where('expiresAt',
              isLessThanOrEqualTo: Timestamp.fromDate(threeDaysAgo))
          .get();

      if (expiredRequests.docs.isEmpty) {
        if (kDebugMode) {
          print('No expired requests found');
        }
        return;
      }

      WriteBatch batch = _firestore.batch();

      for (var doc in expiredRequests.docs) {
        final data = doc.data();

        // Mark as expired
        batch.update(doc.reference, {
          'status': 'EXPIRED',
          'lastUpdatedAt': Timestamp.now(),
          'expiredAt': Timestamp.now(),
        });

        // Create notification
        batch.set(
          _firestore.collection('notifications').doc(),
          {
            'recipientId': data['studentId'],
            'recipientRole': 'STUDENT',
            'type': 'REQUEST_EXPIRED',
            'title': 'Exeat Request Expired',
            'message':
                'Your exeat request has expired after 3 days without approval.',
            'requestId': doc.id,
            'isRead': false,
            'createdAt': Timestamp.now(),
          },
        );
      }

      await batch.commit();

      if (kDebugMode) {
        print('Expired ${expiredRequests.docs.length} requests');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error expiring requests: $e');
      }
    }
  }

  void startExpirationChecker() {
    // Run every hour when app is open
    _timer = Timer.periodic(const Duration(hours: 1), (timer) async {
      await checkAndExpireRequests();
    });

    // Also check immediately on startup
    checkAndExpireRequests();
  }

  void stopExpirationChecker() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopExpirationChecker();
  }
}
