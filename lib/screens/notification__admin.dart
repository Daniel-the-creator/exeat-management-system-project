// screens/notification__admin.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exeat_system/controllers/admin_notification_controller.dart';
import 'package:exeat_system/controllers/request_admin_controller.dart';
import 'package:exeat_system/screens/pending_request.dart';
import 'package:exeat_system/screens/approved_request.dart';
import 'package:exeat_system/screens/declined_request.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminNotifications extends StatefulWidget {
  const AdminNotifications({super.key});

  @override
  State<AdminNotifications> createState() => _AdminNotificationsState();
}

class _AdminNotificationsState extends State<AdminNotifications> {
  final AdminNotificationController notificationController =
      Get.find<AdminNotificationController>();
  final RequestAdminController requestController =
      Get.find<RequestAdminController>();

  String _selectedFilter = "all";
  bool _showUnreadOnly = false;

  List<Map<String, dynamic>> get _filteredNotifications {
    List<Map<String, dynamic>> filtered =
        List.from(notificationController.notifications);

    if (_showUnreadOnly) {
      filtered = filtered.where((notif) => notif["isRead"] == false).toList();
    }

    if (_selectedFilter != "all") {
      filtered =
          filtered.where((notif) => notif["type"] == _selectedFilter).toList();
    }

    return filtered;
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    notificationController.markAsRead(notification['id']);
    _handleNotificationNavigation(notification);
  }

  void _handleNotificationNavigation(Map<String, dynamic> notification) {
    print('📱 Handling notification navigation');
    print('📋 Notification data: ${notification.toString()}');

    String? requestId = _extractRequestId(notification);
    print('🔍 Extracted requestId: $requestId');

    if (requestId != null && requestId.isNotEmpty) {
      _navigateToRequestDetail(requestId);
    } else {
      print('⚠️ No requestId found in notification');
      _showNotificationDetails(notification);
    }
  }

  String? _extractRequestId(Map<String, dynamic> notification) {
    // 1. Check data.requestId
    if (notification["data"] != null &&
        notification["data"] is Map<String, dynamic> &&
        notification["data"]["requestId"] != null) {
      return notification["data"]["requestId"].toString();
    }

    // 2. Check direct requestId field
    if (notification["requestId"] != null) {
      return notification["requestId"].toString();
    }

    return null;
  }

  Future<void> _navigateToRequestDetail(String requestId) async {
    print('🚀 Starting navigation for request: $requestId');

    try {
      print('📡 Fetching request from Firestore...');
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();

      print('📄 Document exists: ${requestDoc.exists}');

      if (!requestDoc.exists) {
        Get.snackbar(
          "Request Not Found",
          "Request with ID $requestId was not found in the system.",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      final requestData = requestDoc.data()!;
      final status = requestData['status']?.toString() ?? 'pending';

      print('📊 Request status: $status');

      _navigateBasedOnStatus(status, requestId);
    } catch (e) {
      print('❌ Error in navigation: $e');
      Get.snackbar(
        "Navigation Error",
        "Could not navigate to request: ${e.toString()}",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _navigateBasedOnStatus(String status, String requestId) {
    print('📍 Navigating based on status: $status');

    // FIX: Use Get.to() instead of Get.off() to preserve navigation stack
    if (status == 'pending_hod' ||
        status == 'pending_student_affairs' ||
        status == 'pending_warden' ||
        status == 'pending') {
      print('➡️ Navigating to PendingRequests');
      Get.to(() => PendingRequests(requestId: requestId));
    } else if (status == 'approved') {
      print('➡️ Navigating to ApprovedRequests');
      Get.to(() => ApprovedRequests(requestId: requestId));
    } else if (status == 'rejected' || status == 'declined') {
      print('➡️ Navigating to DeclinedRequests');
      Get.to(() => DeclinedRequests(requestId: requestId));
    } else {
      print('⚠️ Unknown status, showing notification');
      Get.snackbar(
        "Request Status",
        "Request is in '$status' status",
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNotificationDetailSheet(notification),
    );
  }

  Widget _buildNotificationDetailSheet(Map<String, dynamic> notification) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final color = notificationController
        .getNotificationColor(notification["type"] ?? 'default');
    final icon = notificationController
        .getNotificationIcon(notification["type"] ?? 'default');
    final requestId = _extractRequestId(notification);

    return Container(
      margin: EdgeInsets.all(isSmallScreen ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.2),
                  radius: isSmallScreen ? 18 : 20,
                  child:
                      Icon(icon, color: color, size: isSmallScreen ? 20 : 22),
                ),
                SizedBox(width: isSmallScreen ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification["title"]?.toString() ?? "Notification",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff060121),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notificationController.formatNotificationTime(
                          notification["createdAt"] is DateTime
                              ? notification["createdAt"]
                              : DateTime.now(),
                        ),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isSmallScreen ? 11 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: isSmallScreen ? 18 : 20, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification["message"]?.toString() ?? "",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                if (requestId != null) ...[
                  const SizedBox(height: 16),
                  _buildDetailItem("Request ID", requestId),
                ],
                if (notification["data"] != null &&
                    notification["data"] is Map<String, dynamic>) ...[
                  const SizedBox(height: 16),
                  if (notification["data"]["studentName"] != null)
                    _buildDetailItem("Student",
                        notification["data"]["studentName"]?.toString() ?? ""),
                  if (notification["data"]["oldStatus"] != null)
                    _buildDetailItem("Previous Status",
                        notification["data"]["oldStatus"]?.toString() ?? ""),
                  if (notification["data"]["newStatus"] != null)
                    _buildDetailItem("New Status",
                        notification["data"]["newStatus"]?.toString() ?? ""),
                ],
                const SizedBox(height: 20),
                if (requestId != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToRequestDetail(requestId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 14 : 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        "View Request Details",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Obx(() => Text(
              "Notifications (${notificationController.notifications.length})",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )),
        centerTitle: true,
        backgroundColor: const Color(0xff060121),
        elevation: 2,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == "mark_all_read") {
                  notificationController.markAllAsRead();
                } else if (value == "toggle_unread") {
                  _showUnreadOnly = !_showUnreadOnly;
                } else if (value == "clear_all") {
                  _showClearAllDialog();
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: "mark_all_read",
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, size: 20),
                    SizedBox(width: 8),
                    Text("Mark all as read"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "toggle_unread",
                child: Row(
                  children: [
                    Icon(
                      _showUnreadOnly ? Icons.filter_alt_off : Icons.filter_alt,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(_showUnreadOnly ? "Show all" : "Show unread only"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: "clear_all",
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Clear all notifications",
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip("All", "all"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Status Updates", "STATUS_UPDATE"),
                  const SizedBox(width: 8),
                  _buildFilterChip("New Requests", "NEW_REQUEST"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Comments", "NEW_COMMENT"),
                  const SizedBox(width: 8),
                  _buildFilterChip("System", "SYSTEM"),
                ],
              ),
            ),
          ),

          // Notifications List
          Expanded(
            child: Obx(() {
              final filtered = _filteredNotifications;
              return filtered.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        await notificationController.refreshNotifications();
                      },
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 24,
                          vertical: 16,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final notif = filtered[index];
                          return _buildNotificationCard(notif);
                        },
                      ),
                    );
            }),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All Notifications"),
        content: const Text(
            "Are you sure you want to delete all notifications? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              notificationController.clearAllNotifications();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : "all";
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: const Color(0xff060121).withOpacity(0.1),
      checkmarkColor: const Color(0xff060121),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xff060121) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final color =
        notificationController.getNotificationColor(notif["type"] ?? 'default');
    final icon =
        notificationController.getNotificationIcon(notif["type"] ?? 'default');
    final isUnread = notif["isRead"] == false;
    final requestId = _extractRequestId(notif);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNotificationTap(notif),
          onLongPress: () => _showNotificationOptions(notif),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  color.withOpacity(isUnread ? 0.12 : 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnread ? color.withOpacity(0.3) : Colors.transparent,
                width: isUnread ? 2 : 0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 8, right: 12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 20),
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  radius: 20,
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif["title"]?.toString() ?? "Notification",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xff060121),
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            notificationController.formatNotificationTime(
                              notif["createdAt"] is DateTime
                                  ? notif["createdAt"]
                                  : DateTime.now(),
                            ),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notif["message"]?.toString() ?? "",
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (requestId != null && requestId.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.description,
                                size: 12,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Tap to view request",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationOptions(Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mark_email_read),
              title: const Text("Mark as read"),
              onTap: () {
                Get.back();
                notificationController.markAsRead(notification['id']);
              },
            ),
            if (_extractRequestId(notification) != null)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text("Open Request"),
                onTap: () {
                  Get.back();
                  _handleNotificationNavigation(notification);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete notification",
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Get.back();
                _showDeleteDialog(notification);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Notification"),
        content:
            const Text("Are you sure you want to delete this notification?"),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              notificationController.deleteNotification(notification['id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _showUnreadOnly ? "No unread notifications" : "No notifications",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xff060121),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showUnreadOnly
                ? "You're all caught up!"
                : "Notifications will appear here",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              notificationController.refreshNotifications();
            },
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh"),
          ),
        ],
      ),
    );
  }
}
