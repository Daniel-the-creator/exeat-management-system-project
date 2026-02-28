import 'package:cloud_firestore/cloud_firestore.dart';

class StatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getAdminStatistics(String adminId) async {
    try {
      // Get admin document
      final adminDoc = await _firestore.collection('admins').doc(adminId).get();
      if (!adminDoc.exists) {
        return _getEmptyStats();
      }

      final adminData = adminDoc.data()!;
      final adminRole = adminData['role'];

      // Build query based on admin role
      Query query = _firestore.collection('exeatRequests');

      if (adminRole == 'HOD') {
        final departmentId = adminData['departmentId'];
        if (departmentId != null) {
          query = query.where('departmentId', isEqualTo: departmentId);
        }
      } else if (adminRole == 'HALL_WARDEN') {
        final hallId = adminData['hallId'];
        if (hallId != null) {
          query = query.where('hallId', isEqualTo: hallId);
        }
      }

      // Execute query
      final snapshot = await query.get();

      // Initialize statistics
      final Map<String, dynamic> stats = {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'expired': 0,
        'total': snapshot.docs.length,
        'byPriority': {
          'EMERGENCY': 0,
          'MEDICAL': 0,
          'FAMILY': 0,
          'NORMAL': 0,
        },
      };

      // Process each document
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final status = (data['status'] as String?)?.toUpperCase() ?? '';
        final priority =
            (data['priorityLevel'] as String?)?.toUpperCase() ?? 'NORMAL';

        // Count by status
        if (status.contains('PENDING')) {
          stats['pending'] = (stats['pending'] as int) + 1;
        } else if (status == 'APPROVED') {
          stats['approved'] = (stats['approved'] as int) + 1;
        } else if (status == 'REJECTED') {
          stats['rejected'] = (stats['rejected'] as int) + 1;
        } else if (status == 'EXPIRED') {
          stats['expired'] = (stats['expired'] as int) + 1;
        }

        // Count by priority
        final byPriority = stats['byPriority'] as Map<String, dynamic>;
        if (byPriority.containsKey(priority)) {
          byPriority[priority] = (byPriority[priority] as int) + 1;
        } else {
          // If priority is not in our list, count it as NORMAL
          byPriority['NORMAL'] = (byPriority['NORMAL'] as int) + 1;
        }
      }

      return stats;
    } catch (e) {
      print('Error getting admin statistics: $e');
      return _getEmptyStats();
    }
  }

  // Alternative: Simpler method for just counts
  Future<Map<String, int>> getQuickStats(String adminId) async {
    try {
      final adminDoc = await _firestore.collection('admins').doc(adminId).get();
      if (!adminDoc.exists) {
        return {
          'pending': 0,
          'approved': 0,
          'rejected': 0,
          'expired': 0,
          'total': 0,
        };
      }

      final adminData = adminDoc.data()!;
      final adminRole = adminData['role'];

      Query query = _firestore.collection('exeatRequests');

      if (adminRole == 'HOD') {
        final departmentId = adminData['departmentId'];
        if (departmentId != null) {
          query = query.where('departmentId', isEqualTo: departmentId);
        }
      } else if (adminRole == 'HALL_WARDEN') {
        final hallId = adminData['hallId'];
        if (hallId != null) {
          query = query.where('hallId', isEqualTo: hallId);
        }
      }

      final snapshot = await query.get();

      int pending = 0, approved = 0, rejected = 0, expired = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final status = (data['status'] as String?) ?? '';

        if (status.contains('PENDING')) {
          pending++;
        } else if (status == 'APPROVED') {
          approved++;
        } else if (status == 'REJECTED') {
          rejected++;
        } else if (status == 'EXPIRED') {
          expired++;
        }
      }

      return {
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'expired': expired,
        'total': snapshot.docs.length,
      };
    } catch (e) {
      print('Error getting quick stats: $e');
      return {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'expired': 0,
        'total': 0,
      };
    }
  }

  // Get priority breakdown
  Future<Map<String, int>> getPriorityStats(String adminId) async {
    try {
      final adminDoc = await _firestore.collection('admins').doc(adminId).get();
      if (!adminDoc.exists) {
        return {
          'EMERGENCY': 0,
          'MEDICAL': 0,
          'FAMILY': 0,
          'NORMAL': 0,
        };
      }

      final adminData = adminDoc.data()!;
      final adminRole = adminData['role'];

      Query query = _firestore.collection('exeatRequests');

      if (adminRole == 'HOD') {
        final departmentId = adminData['departmentId'];
        if (departmentId != null) {
          query = query.where('departmentId', isEqualTo: departmentId);
        }
      } else if (adminRole == 'HALL_WARDEN') {
        final hallId = adminData['hallId'];
        if (hallId != null) {
          query = query.where('hallId', isEqualTo: hallId);
        }
      }

      final snapshot = await query.get();

      Map<String, int> priorityStats = {
        'EMERGENCY': 0,
        'MEDICAL': 0,
        'FAMILY': 0,
        'NORMAL': 0,
      };

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final priority =
            (data['priorityLevel'] as String?)?.toUpperCase() ?? 'NORMAL';

        // Safely increment count
        if (priorityStats.containsKey(priority)) {
          priorityStats[priority] = (priorityStats[priority] ?? 0) + 1;
        } else {
          priorityStats['NORMAL'] = (priorityStats['NORMAL'] ?? 0) + 1;
        }
      }

      return priorityStats;
    } catch (e) {
      print('Error getting priority stats: $e');
      return {
        'EMERGENCY': 0,
        'MEDICAL': 0,
        'FAMILY': 0,
        'NORMAL': 0,
      };
    }
  }

  // Helper method for empty stats
  Map<String, dynamic> _getEmptyStats() {
    return {
      'pending': 0,
      'approved': 0,
      'rejected': 0,
      'expired': 0,
      'total': 0,
      'byPriority': {
        'EMERGENCY': 0,
        'MEDICAL': 0,
        'FAMILY': 0,
        'NORMAL': 0,
      },
    };
  }

  // Real-time stream of counts
  Stream<Map<String, int>> getRealTimeCounts(
      {String? departmentId, String? hallId}) {
    return _firestore.collection('exeatRequests').snapshots().map((snapshot) {
      int pending = 0, approved = 0, rejected = 0, expired = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        // Apply filters
        if (departmentId != null && data['departmentId'] != departmentId) {
          continue;
        }
        if (hallId != null && data['hallId'] != hallId) continue;

        final status = (data['status'] as String?) ?? '';

        if (status.contains('PENDING')) {
          pending++;
        } else if (status == 'APPROVED') {
          approved++;
        } else if (status == 'REJECTED') {
          rejected++;
        } else if (status == 'EXPIRED') {
          expired++;
        }
      }

      return {
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'expired': expired,
        'total': snapshot.docs.length,
      };
    });
  }
}
