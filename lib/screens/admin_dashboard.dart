// screens/admin_dashboard.dart
import 'package:exeat_system/screens/admin_profile.dart';
import 'package:exeat_system/screens/approved_request.dart';
import 'package:exeat_system/screens/data_analysis.dart';
import 'package:exeat_system/screens/declined_request.dart';
import 'package:exeat_system/screens/notification__admin.dart';
import 'package:exeat_system/screens/pending_request.dart';
import 'package:exeat_system/controllers/request_admin_controller.dart';
import 'package:exeat_system/controllers/admin_notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final requestController = Get.find<RequestAdminController>();
  late final AdminNotificationController notificationController;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // Initialize notification controller
    notificationController = Get.find<AdminNotificationController>();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();

    // Load notifications after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notificationController.loadNotifications();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      await requestController.refreshRequests();
      await notificationController.refreshNotifications();

      // Force UI update
      if (mounted) {
        setState(() {});
      }

      Get.snackbar(
        'Refreshed',
        'Data updated successfully',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 1),
      );
    } catch (e) {
      print('Error refreshing data: $e');
      Get.snackbar(
        'Error',
        'Failed to refresh data: $e',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isSmallScreen = screenWidth < 600;

    double paddingValue = isSmallScreen ? 16 : 24;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff060121),
              Color(0xff1a0f3e),
              Color(0xff2d1b5e),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: EdgeInsets.all(paddingValue),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome Back",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Admin Dashboard",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Refresh button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: _refreshData,
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Notifications button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Obx(() {
                            final unreadCount =
                                notificationController.unreadCount.value;
                            return Stack(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      Get.to(() => const AdminNotifications()),
                                  icon: const Icon(
                                    Icons.notifications_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        unreadCount > 99
                                            ? '99+'
                                            : unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () => Get.to(() => const ProfileAdmin()),
                            icon: const Icon(
                              Icons.settings_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content Area
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: paddingValue * 0.5),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(paddingValue),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Cards
                        _buildAnimatedWidget(
                          delay: 0.0,
                          child: Obx(() {
                            final screenWidth =
                                MediaQuery.of(context).size.width;
                            final isSmallScreen = screenWidth < 600;

                            if (isSmallScreen) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: (screenWidth - 48) / 2.2,
                                      child: _statCard(
                                        "Pending",
                                        requestController.pendingCount.value,
                                        Icons.hourglass_empty_rounded,
                                        Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: (screenWidth - 48) / 2.2,
                                      child: _statCard(
                                        "Approved",
                                        requestController.approvedCount.value,
                                        Icons.check_circle_rounded,
                                        Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: (screenWidth - 48) / 2.2,
                                      child: _statCard(
                                        "Declined",
                                        requestController.declinedCount.value,
                                        Icons.cancel_rounded,
                                        Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: _statCard(
                                    "Pending",
                                    requestController.pendingCount.value,
                                    Icons.hourglass_empty_rounded,
                                    Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _statCard(
                                    "Approved",
                                    requestController.approvedCount.value,
                                    Icons.check_circle_rounded,
                                    Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _statCard(
                                    "Declined",
                                    requestController.declinedCount.value,
                                    Icons.cancel_rounded,
                                    Colors.red,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),

                        const SizedBox(height: 20),

                        // Notification Stats Card
                        _buildAnimatedWidget(
                          delay: 0.05,
                          child: Obx(() {
                            final unreadCount =
                                notificationController.unreadCount.value;
                            final notifications =
                                notificationController.notifications;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.2),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Stack(
                                      children: [
                                        const Icon(
                                          Icons.notifications_rounded,
                                          color: Colors.blue,
                                          size: 24,
                                        ),
                                        if (unreadCount > 0)
                                          Positioned(
                                            right: -2,
                                            top: -2,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                unreadCount > 99
                                                    ? '99+'
                                                    : unreadCount.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Notifications",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xff060121),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          unreadCount > 0
                                              ? "$unreadCount unread notification${unreadCount > 1 ? 's' : ''}"
                                              : "No unread notifications",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (notifications.isNotEmpty &&
                                      unreadCount > 0)
                                    TextButton(
                                      onPressed: () => notificationController
                                          .markAllAsRead(),
                                      child: const Text(
                                        "Mark all read",
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 32),

                        // Quick Actions Header
                        _buildAnimatedWidget(
                          delay: 0.1,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xff060121),
                                      Color(0xff2d1b5e),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.flash_on_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Quick Actions",
                                style: TextStyle(
                                  color: Color(0xff060121),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Recent Pending Requests
                        Obx(() {
                          final pendingRequests =
                              requestController.pendingRequests;

                          if (pendingRequests.isNotEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    "Recent Pending Requests",
                                    style: TextStyle(
                                      color: Color(0xff060121),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: pendingRequests.length > 3
                                      ? 3
                                      : pendingRequests.length,
                                  itemBuilder: (context, index) {
                                    final request = pendingRequests[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.orange.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              Colors.orange.withOpacity(0.1),
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.orange,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          request.studentName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              request.studentMatric,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              request.destination,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getPriorityColor(
                                                    request.priorityLevel)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            request.priorityLevel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: _getPriorityColor(
                                                  request.priorityLevel),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        onTap: () {
                                          Get.to(() => const PendingRequests());
                                        },
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () =>
                                        Get.to(() => const PendingRequests()),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "View all pending requests",
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Colors.blue,
                                          size: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            );
                          } else {
                            return const SizedBox();
                          }
                        }),

                        // Action Cards
                        _buildAnimatedWidget(
                          delay: 0.15,
                          child: _actionCard(
                            icon: Icons.pending_actions_rounded,
                            title: "Pending Requests",
                            description:
                                "View and approve pending exeat requests from students.",
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade300,
                                Colors.orange.shade400
                              ],
                            ),
                            onTap: () => Get.to(() => const PendingRequests()),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildAnimatedWidget(
                          delay: 0.2,
                          child: _actionCard(
                            icon: Icons.check_circle_rounded,
                            title: "Approved Requests",
                            description: "See all approved exeat requests.",
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade300,
                                Colors.green.shade400
                              ],
                            ),
                            onTap: () => Get.to(() => const ApprovedRequests()),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildAnimatedWidget(
                          delay: 0.25,
                          child: _actionCard(
                            icon: Icons.cancel_rounded,
                            title: "Declined Requests",
                            description: "Review all declined exeat requests.",
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade300,
                                Colors.red.shade400
                              ],
                            ),
                            onTap: () => Get.to(() => const DeclinedRequests()),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildAnimatedWidget(
                          delay: 0.3,
                          child: _actionCard(
                            icon: Icons.notifications_rounded,
                            title: "Notifications",
                            description:
                                "Check important updates or system alerts.",
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade300,
                                Colors.blue.shade400
                              ],
                            ),
                            onTap: () =>
                                Get.to(() => const AdminNotifications()),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildAnimatedWidget(
                          delay: 0.35,
                          child: _actionCard(
                            icon: Icons.people_rounded,
                            title: "Students",
                            description:
                                "View student list and monitor exeat activity.",
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade300,
                                Colors.purple.shade400
                              ],
                            ),
                            onTap: () =>
                                Get.to(() => const StudentsExeatListScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'EMERGENCY':
        return Colors.red;
      case 'MEDICAL':
        return Colors.orange;
      case 'FAMILY':
        return Colors.blue;
      case 'NORMAL':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildAnimatedWidget({required double delay, required Widget child}) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final animationValue = Curves.easeOutCubic.transform(
          (_animationController.value - delay).clamp(0.0, 1.0) / (1.0 - delay),
        );

        return Transform.translate(
          offset: Offset(0, 30 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _statCard(String title, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            "$count",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String description,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: const Color(0xff060121),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
