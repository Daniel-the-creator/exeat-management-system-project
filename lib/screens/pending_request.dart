import 'package:exeat_system/model/exeat_request.dart';
import 'package:exeat_system/model/request_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:exeat_system/controllers/request_admin_controller.dart';

class PendingRequests extends StatefulWidget {
  final String? requestId; // Add this parameter
  final bool? showComments; // Add this parameter

  const PendingRequests({super.key, this.requestId, this.showComments});

  @override
  State<PendingRequests> createState() => _PendingRequestsState();
}

class _PendingRequestsState extends State<PendingRequests>
    with SingleTickerProviderStateMixin {
  final requestController = Get.find<RequestAdminController>();
  late AnimationController _animationController;
  late double screenHeight;

  // Track if we need to highlight a specific request
  bool _shouldHighlightRequest = false;
  String? _highlightRequestId;
  int? _highlightedIndex;

  // Priority filter state
  String _selectedPriority = 'ALL';
  final List<String> _priorities = [
    'ALL',
    'EMERGENCY',
    'MEDICAL',
    'FAMILY',
    'NORMAL'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();

    // Check if we have a requestId to highlight
    if (widget.requestId != null && widget.requestId!.isNotEmpty) {
      _highlightRequestId = widget.requestId;
      _shouldHighlightRequest = true;

      // Delay to ensure controller has loaded requests
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _findAndHighlightRequest();
      });
    }
  }

  void _findAndHighlightRequest() {
    if (_highlightRequestId == null) return;

    final requests = requestController.pendingRequests;
    for (int i = 0; i < requests.length; i++) {
      if (requests[i].requestId == _highlightRequestId) {
        setState(() {
          _highlightedIndex = i;
        });

        // Optional: Scroll to the highlighted request
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedRequest();
        });
        break;
      }
    }
  }

  void _scrollToHighlightedRequest() {
    if (_highlightedIndex != null) {
      // You can implement scroll logic here if using a ScrollController
      // For now, we'll just highlight it visually
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showRequestDetails(RequestModel request,
      {bool fromNotification = false}) {
    final exeatRequest = ExeatRequest(
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

    final screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        insetPadding: isSmallScreen
            ? const EdgeInsets.all(16)
            : EdgeInsets.symmetric(
                horizontal: screenWidth * 0.1,
                vertical: 40,
              ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? screenWidth * 0.95 : 600,
            maxHeight: isSmallScreen ? screenHeight * 0.85 : screenHeight * 0.9,
          ),
          child: Container(
            padding: isSmallScreen
                ? const EdgeInsets.all(16)
                : const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header with notification indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    fromNotification
                                        ? Colors.blue.shade400
                                        : Colors.orange.shade400,
                                    fromNotification
                                        ? Colors.blue.shade600
                                        : Colors.orange.shade600
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                fromNotification
                                    ? Icons.notifications_rounded
                                    : Icons.pending_actions_rounded,
                                color: Colors.white,
                                size: isSmallScreen ? 20 : 24,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fromNotification
                                        ? "Notification - Request Details"
                                        : "Request Details",
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 18 : 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xff060121),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 8 : 12,
                                      vertical: isSmallScreen ? 3 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getPriorityColor(
                                              request.priorityLevel)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      request.priorityLevel,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 10 : 11,
                                        fontWeight: FontWeight.bold,
                                        color: _getPriorityColor(
                                            request.priorityLevel),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Details Section - Responsive layout
                  if (isSmallScreen)
                    // Mobile Layout - Single Column
                    Column(
                      children: [
                        _buildDetailRow(
                          context,
                          Icons.person,
                          "Student Name",
                          exeatRequest.studentName,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.school,
                          "Matric Number",
                          exeatRequest.studentMatric,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.email,
                          "Email",
                          request.studentEmail,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.phone,
                          "Phone",
                          request.studentPhone,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.location_on,
                          "Destination",
                          exeatRequest.destination,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.calendar_today,
                          "Departure Date",
                          "${exeatRequest.leaveDate} at ${exeatRequest.leaveTime}",
                        ),
                        _buildDetailRow(
                          context,
                          Icons.event,
                          "Return Date",
                          "${exeatRequest.returnDate} at ${exeatRequest.returnTime}",
                        ),
                        _buildDetailRow(
                          context,
                          Icons.description,
                          "Reason",
                          exeatRequest.reason,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.contacts,
                          "Emergency Contact",
                          "${request.contactPerson} (${request.contactNumber})",
                        ),
                        if (request.guardianApproval.isNotEmpty)
                          _buildDetailRow(
                            context,
                            Icons.verified,
                            "Guardian Approval",
                            request.guardianApproval,
                          ),
                      ],
                    )
                  else
                    // Desktop/Tablet Layout - Two Columns
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isMediumScreen ? 1 : 2,
                      childAspectRatio: isMediumScreen ? 4 : 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 12,
                      children: [
                        _buildDetailGridItem(
                          context,
                          Icons.person,
                          "Student Name",
                          exeatRequest.studentName,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.school,
                          "Matric Number",
                          exeatRequest.studentMatric,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.email,
                          "Email",
                          request.studentEmail,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.phone,
                          "Phone",
                          request.studentPhone,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.location_on,
                          "Destination",
                          exeatRequest.destination,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.calendar_today,
                          "Departure Date",
                          "${exeatRequest.leaveDate} at ${exeatRequest.leaveTime}",
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.event,
                          "Return Date",
                          "${exeatRequest.returnDate} at ${exeatRequest.returnTime}",
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.description,
                          "Reason",
                          exeatRequest.reason,
                          isFullWidth: true,
                          crossAxisCount: isMediumScreen ? 1 : 2,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.contacts,
                          "Emergency Contact",
                          "${request.contactPerson} (${request.contactNumber})",
                        ),
                        if (request.guardianApproval.isNotEmpty)
                          _buildDetailGridItem(
                            context,
                            Icons.verified,
                            "Guardian Approval",
                            request.guardianApproval,
                          ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Action Buttons - Fixed spacing issue
                  isSmallScreen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _declineRequest(request.requestId);
                                },
                                icon: const Icon(Icons.cancel_rounded),
                                label: Text(
                                  "Decline",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(
                                      color: Colors.red, width: 2),
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 14 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _approveRequest(request.requestId);
                                },
                                icon: const Icon(Icons.check_circle_rounded),
                                label: Text(
                                  "Approve",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 14 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _declineRequest(request.requestId);
                                },
                                icon: const Icon(Icons.cancel_rounded),
                                label: const Text("Decline"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(
                                      color: Colors.red, width: 2),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _approveRequest(request.requestId);
                                },
                                icon: const Icon(Icons.check_circle_rounded),
                                label: const Text("Approve"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
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

  // For mobile/single column layout
  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
            decoration: BoxDecoration(
              color: const Color(0xff060121).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: isSmallScreen ? 16 : 18,
              color: const Color(0xff060121),
            ),
          ),
          SizedBox(width: isSmallScreen ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 15,
                    color: const Color(0xff060121),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // For grid items in desktop/tablet layout
  Widget _buildDetailGridItem(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isFullWidth = false,
    int crossAxisCount = 2,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;

    if (isSmallScreen) {
      return _buildDetailRow(context, icon, label, value);
    }

    return SizedBox(
      width: isFullWidth && crossAxisCount == 2 ? double.infinity : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff060121).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xff060121),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xff060121),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(String requestId) async {
    try {
      await requestController.updateRequestStatus(
        requestId: requestId,
        newStatus: 'approved',
        adminNote: 'Approved by admin',
      );
      Get.snackbar(
        'Success',
        'Request approved successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to approve request: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _declineRequest(String requestId) async {
    final screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;
    final TextEditingController reasonController = TextEditingController();

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        insetPadding: isSmallScreen
            ? const EdgeInsets.all(16)
            : EdgeInsets.symmetric(
                horizontal: screenWidth * 0.1,
                vertical: 40,
              ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? screenWidth * 0.95 : 500,
            maxHeight: isSmallScreen ? screenHeight * 0.7 : screenHeight * 0.6,
          ),
          child: Container(
            padding: isSmallScreen
                ? const EdgeInsets.all(16)
                : const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Reason for Decline",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff060121),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  TextField(
                    controller: reasonController,
                    maxLines: isSmallScreen ? 3 : 4,
                    decoration: InputDecoration(
                      hintText: "Enter reason for declining this request...",
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 24),

                  // Buttons - Fixed spacing issue
                  isSmallScreen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextButton(
                              onPressed: () => Get.back(),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (reasonController.text.trim().isEmpty) {
                                    Get.snackbar(
                                      'Error',
                                      'Please enter a reason',
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                    );
                                    return;
                                  }

                                  Get.back();
                                  try {
                                    await requestController.updateRequestStatus(
                                      requestId: requestId,
                                      newStatus: 'rejected',
                                      adminNote: reasonController.text.trim(),
                                    );
                                    Get.snackbar(
                                      'Success',
                                      'Request declined',
                                      backgroundColor: Colors.orange,
                                      colorText: Colors.white,
                                    );
                                  } catch (e) {
                                    Get.snackbar(
                                      'Error',
                                      'Failed to decline request: $e',
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  "Decline",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text("Cancel"),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                if (reasonController.text.trim().isEmpty) {
                                  Get.snackbar(
                                    'Error',
                                    'Please enter a reason',
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                  return;
                                }

                                Get.back();
                                try {
                                  await requestController.updateRequestStatus(
                                    requestId: requestId,
                                    newStatus: 'rejected',
                                    adminNote: reasonController.text.trim(),
                                  );
                                  Get.snackbar(
                                    'Success',
                                    'Request declined',
                                    backgroundColor: Colors.orange,
                                    colorText: Colors.white,
                                  );
                                } catch (e) {
                                  Get.snackbar(
                                    'Error',
                                    'Failed to decline request: $e',
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text("Decline"),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;

    double paddingValue = isSmallScreen ? 16 : 24;
    double headerPadding = isSmallScreen ? 16 : 24;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff060121), Color(0xff1a0f3e)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(headerPadding),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _shouldHighlightRequest
                                ? "Pending Request"
                                : "Pending Requests",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Obx(() => Text(
                                "${requestController.pendingRequests.length} pending requests",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
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
                  child: Obx(() {
                    var filteredRequests =
                        requestController.pendingRequests.where((request) {
                      if (_selectedPriority == 'ALL') return true;
                      return request.priorityLevel.toUpperCase() ==
                          _selectedPriority;
                    }).toList();

                    return Column(
                      children: [
                        _buildFilterSection(isSmallScreen),
                        Expanded(
                          child: filteredRequests.isEmpty
                              ? _buildEmptyState(isSmallScreen)
                              : ListView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                    paddingValue,
                                    0,
                                    paddingValue,
                                    paddingValue,
                                  ),
                                  itemCount: filteredRequests.length,
                                  itemBuilder: (context, index) {
                                    final request = filteredRequests[index];
                                    return _buildAnimatedRequestCard(
                                      request,
                                      index,
                                      isSmallScreen,
                                      isMediumScreen,
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedRequestCard(
    RequestModel request,
    int index,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    final isHighlighted = _highlightedIndex == index;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animationValue = Curves.easeOutCubic.transform(
          (_animationController.value - delay).clamp(0.0, 1.0) / (1.0 - delay),
        );
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animationValue)),
          child: Opacity(opacity: animationValue, child: child),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          color: isHighlighted ? Colors.orange.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
          border: Border.all(
              color: isHighlighted
                  ? Colors.orange.shade600
                  : Colors.orange.withOpacity(0.3),
              width: isHighlighted ? 3 : 2),
          boxShadow: [
            BoxShadow(
              color: (isHighlighted
                  ? Colors.orange.shade300
                  : Colors.orange.withOpacity(0.1)),
              blurRadius: isSmallScreen ? 8 : 15,
              offset: const Offset(0, 4),
            ),
            if (isHighlighted)
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 0),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                _showRequestDetails(request, fromNotification: isHighlighted),
            borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              child: Row(
                children: [
                  // Highlight indicator for notification requests
                  if (isHighlighted)
                    Container(
                      width: 4,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      child: const SizedBox(),
                    ),

                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isHighlighted
                            ? [Colors.blue.shade400, Colors.blue.shade600]
                            : [Colors.orange.shade400, Colors.orange.shade600],
                      ),
                      borderRadius:
                          BorderRadius.circular(isSmallScreen ? 12 : 16),
                      boxShadow: [
                        BoxShadow(
                          color: (isHighlighted ? Colors.blue : Colors.orange)
                              .withOpacity(0.3),
                          blurRadius: isSmallScreen ? 6 : 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isHighlighted
                          ? Icons.notifications_rounded
                          : Icons.pending_actions_rounded,
                      color: Colors.white,
                      size: isSmallScreen ? 22 : 28,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                request.studentName,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 17,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xff060121),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 8 : 10,
                                vertical: isSmallScreen ? 4 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(request.priorityLevel)
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(
                                    isSmallScreen ? 8 : 12),
                              ),
                              child: Text(
                                request.priorityLevel,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11 : 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _getPriorityColor(request.priorityLevel),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Text(
                          request.studentMatric,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: isSmallScreen ? 16 : 18,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: isSmallScreen ? 6 : 8),
                            Expanded(
                              child: Text(
                                request.destination,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 15,
                                  color: Colors.grey[700],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: isSmallScreen ? 14 : 16,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: isSmallScreen ? 6 : 8),
                            Expanded(
                              child: Text(
                                "${request.leaveDate} ${request.leaveTime} → ${request.returnDate} ${request.returnTime}",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.grey[400],
                    size: isSmallScreen ? 16 : 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isSmallScreen) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: isSmallScreen ? 60 : 80,
                color: Colors.orange.withOpacity(0.5),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            Text(
              "No Pending Requests",
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xff060121),
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              "All requests have been processed",
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isSmallScreen) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _priorities.length,
        itemBuilder: (context, index) {
          final priority = _priorities[index];
          final isSelected = _selectedPriority == priority;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                priority,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedPriority = priority;
                });
              },
              selectedColor: const Color(0xff060121),
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color:
                      isSelected ? const Color(0xff060121) : Colors.grey[300]!,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
