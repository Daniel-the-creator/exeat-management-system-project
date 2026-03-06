// screens/request_history.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:exeat_system/controllers/request_controller.dart';
import 'package:exeat_system/model/request_model.dart';
import 'package:exeat_system/services/pdf_service.dart';

class RequestHistory extends StatefulWidget {
  const RequestHistory({super.key});

  @override
  State<RequestHistory> createState() => _RequestHistoryState();
}

class _RequestHistoryState extends State<RequestHistory>
    with SingleTickerProviderStateMixin {
  final RequestController _requestController = Get.find<RequestController>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late double screenHeight;

  String _selectedFilter = 'All';
  List<String> _filters = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Initialize the request controller for this user
    _requestController.initializeForUser();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<RequestModel> getFilteredRequests() {
    final allRequests = _requestController.studentRequests;

    if (_selectedFilter == 'All') return allRequests;

    return allRequests.where((req) {
      if (_selectedFilter == 'Pending') {
        return req.status.contains('pending');
      } else if (_selectedFilter == 'Approved') {
        return req.status == 'approved';
      } else if (_selectedFilter == 'Rejected') {
        return req.status == 'rejected';
      }
      return true;
    }).toList();
  }

  Color getStatusColor(String status) {
    if (status == 'pending') return Colors.orange;
    if (status == 'approved') return Colors.green;
    if (status == 'rejected') return Colors.red;
    if (status == 'completed') return Colors.blue;
    return Colors.grey;
  }

  IconData getStatusIcon(String status) {
    if (status == 'pending') return Icons.pending_rounded;
    if (status == 'approved') return Icons.check_circle_rounded;
    if (status == 'rejected') return Icons.cancel_rounded;
    if (status == 'completed') return Icons.done_all_rounded;
    return Icons.history_rounded;
  }

  String getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  void _showRequestDetails(RequestModel request) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: getStatusColor(request.status)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                getStatusIcon(request.status),
                                color: getStatusColor(request.status),
                                size: isSmallScreen ? 20 : 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Request Details",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: getStatusColor(request.status),
                                ),
                                overflow: TextOverflow.ellipsis,
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

                  // Details Grid - Responsive based on screen size
                  if (isSmallScreen)
                    // Mobile Layout - Single Column
                    Column(
                      children: [
                        _buildDetailRow(
                          context,
                          Icons.person,
                          "Student Name",
                          request.studentName,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.school,
                          "Matric Number",
                          request.studentMatric,
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
                          request.destination,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.calendar_today,
                          "Departure Date",
                          request.leaveDate,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.access_time,
                          "Departure Time",
                          request.leaveTime,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.event,
                          "Return Date",
                          request.returnDate,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.timer,
                          "Return Time",
                          request.returnTime,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.description,
                          "Reason",
                          request.reason,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.contact_page,
                          "Contact Person",
                          request.contactPerson,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.contact_phone,
                          "Contact Number",
                          request.contactNumber,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.family_restroom,
                          "Guardian Approval",
                          request.guardianApproval,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.label,
                          "Priority",
                          request.priorityLevel,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.info,
                          "Status",
                          getStatusText(request.status),
                        ),
                        if (request.adminNote != null &&
                            request.adminNote!.isNotEmpty)
                          _buildDetailRow(
                            context,
                            Icons.note,
                            "Admin Note",
                            request.adminNote!,
                          ),
                        if (request.processedBy != null)
                          _buildDetailRow(
                            context,
                            Icons.person_pin,
                            "Processed By",
                            request.processedBy!,
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
                          request.studentName,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.school,
                          "Matric Number",
                          request.studentMatric,
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
                          request.destination,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.calendar_today,
                          "Departure Date",
                          request.leaveDate,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.access_time,
                          "Departure Time",
                          request.leaveTime,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.event,
                          "Return Date",
                          request.returnDate,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.timer,
                          "Return Time",
                          request.returnTime,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.description,
                          "Reason",
                          request.reason,
                          isFullWidth: true,
                          crossAxisCount: isMediumScreen ? 1 : 2,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.contact_page,
                          "Contact Person",
                          request.contactPerson,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.contact_phone,
                          "Contact Number",
                          request.contactNumber,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.family_restroom,
                          "Guardian Approval",
                          request.guardianApproval,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.label,
                          "Priority",
                          request.priorityLevel,
                        ),
                        _buildDetailGridItem(
                          context,
                          Icons.info,
                          "Status",
                          getStatusText(request.status),
                        ),
                        if (request.adminNote != null &&
                            request.adminNote!.isNotEmpty)
                          _buildDetailGridItem(
                            context,
                            Icons.note,
                            "Admin Note",
                            request.adminNote!,
                            isFullWidth: true,
                            crossAxisCount: isMediumScreen ? 1 : 2,
                          ),
                        if (request.processedBy != null)
                          _buildDetailGridItem(
                            context,
                            Icons.person_pin,
                            "Processed By",
                            request.processedBy!,
                          ),
                      ],
                    ),

                  const SizedBox(height: 24),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (request.status == 'approved') ...[
                        ElevatedButton.icon(
                          onPressed: () =>
                              PdfService.generateAndPrintExeat(request),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text("DOWNLOAD PDF"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 24,
                              vertical: isSmallScreen ? 12 : 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: getStatusColor(request.status),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 24 : 32,
                            vertical: isSmallScreen ? 12 : 16,
                          ),
                          minimumSize: Size(isSmallScreen ? 120 : 150, 50),
                        ),
                        child: Text(
                          "CLOSE",
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
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

  // For mobile/single column layout
  Widget _buildDetailRow(
      BuildContext context, IconData icon, String label, String value) {
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;
    double paddingValue = isSmallScreen ? 16 : 24;

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
                padding: EdgeInsets.all(paddingValue),
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
                          const Text(
                            "Request History",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Obx(() => Text(
                                "${_requestController.studentRequests.length} total requests",
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
                  child: Column(
                    children: [
                      // Filter Section (Status)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: paddingValue, vertical: 8),
                        height: 55,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _filters.map((filter) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter),
                                selected: _selectedFilter == filter,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = filter;
                                  });
                                },
                                backgroundColor:
                                    const Color(0xff060121).withOpacity(0.05),
                                selectedColor: const Color(0xff060121),
                                labelStyle: TextStyle(
                                  color: _selectedFilter == filter
                                      ? Colors.white
                                      : const Color(0xff060121),
                                  fontSize: 12,
                                  fontWeight: _selectedFilter == filter
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                checkmarkColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: _selectedFilter == filter
                                        ? const Color(0xff060121)
                                        : Colors.grey[300]!,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // List
                      Expanded(
                        child: Obx(() {
                          final filteredRequests = getFilteredRequests();

                          if (filteredRequests.isEmpty) {
                            return _buildEmptyState();
                          }

                          return ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                                paddingValue, 0, paddingValue, paddingValue),
                            itemCount: filteredRequests.length,
                            itemBuilder: (context, index) {
                              final request = filteredRequests[index];
                              return FadeTransition(
                                opacity: _fadeAnimation,
                                child: _buildRequestCard(request),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(RequestModel request) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        border: Border.all(
          color: getStatusColor(request.status).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: getStatusColor(request.status).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showRequestDetails(request),
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                  decoration: BoxDecoration(
                    color: getStatusColor(request.status).withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(isSmallScreen ? 12 : 16),
                  ),
                  child: Icon(
                    getStatusIcon(request.status),
                    color: getStatusColor(request.status),
                    size: isSmallScreen ? 24 : 28,
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
                              request.destination,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 17,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff060121),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 6 : 8,
                              vertical: isSmallScreen ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: getStatusColor(request.status)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              getStatusText(request.status),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: getStatusColor(request.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 4),
                      Text(
                        request.studentMatric,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 6 : 8,
                              vertical: isSmallScreen ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(request.priorityLevel)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              request.priorityLevel,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: _getPriorityColor(request.priorityLevel),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: isSmallScreen ? 12 : 14,
                                  color: Colors.grey[600]),
                              SizedBox(width: isSmallScreen ? 2 : 4),
                              Text(
                                request.createdAt
                                    .toDate()
                                    .toString()
                                    .split(' ')[0],
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11 : 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      Text(
                        "${request.leaveDate} ${request.leaveTime} → ${request.returnDate} ${request.returnTime}",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (request.adminNote != null &&
                          request.adminNote!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: isSmallScreen ? 6 : 8),
                          child: Text(
                            "Note: ${request.adminNote!}",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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

  Widget _buildEmptyState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
              decoration: BoxDecoration(
                color: const Color(0xff060121).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: isSmallScreen ? 60 : 80,
                color: const Color(0xff060121).withOpacity(0.5),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            Text(
              "No Requests Found",
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xff060121),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 4 : 8),
            Text(
              _selectedFilter == 'All'
                  ? "You haven't submitted any exeat requests yet"
                  : "No ${_selectedFilter.toLowerCase()} requests found",
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 15,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
