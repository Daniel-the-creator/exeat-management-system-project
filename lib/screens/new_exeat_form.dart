import 'package:exeat_system/screens/home_page.dart';
import 'package:exeat_system/services/exeat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NewExeatForm extends StatefulWidget {
  const NewExeatForm({super.key});

  @override
  State<NewExeatForm> createState() => _NewExeatFormState();
}

class _NewExeatFormState extends State<NewExeatForm>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ExeatService _exeatService = ExeatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? selectedApproval;
  String? selectedDestination;
  String? selectedPriority;
  final TextEditingController leaveDateController = TextEditingController();
  final TextEditingController leaveTimeController = TextEditingController();
  final TextEditingController returnDateController = TextEditingController();
  final TextEditingController returnTimeController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();

  final List<String> approval = ['APPROVED', 'PENDING', 'DECLINED'];
  final List<String> destinations = [
    'Lagos',
    'Abuja',
    'Ibadan',
    'Port Harcourt',
    'Enugu',
    'Kano',
    'Kaduna',
    'Benin',
    'Warri',
    'Calabar'
  ];
  final List<String> priorities = ['NORMAL', 'FAMILY', 'MEDICAL', 'EMERGENCY'];

  final bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();

    // Set default values
    selectedPriority = 'NORMAL';

    // Add listeners for phone number formatting
    phoneController.addListener(() {
      _formatPhoneNumber(phoneController);
    });

    contactNumberController.addListener(() {
      _formatPhoneNumber(contactNumberController);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    leaveDateController.dispose();
    leaveTimeController.dispose();
    returnDateController.dispose();
    returnTimeController.dispose();
    phoneController.dispose();
    reasonController.dispose();
    contactPersonController.dispose();
    contactNumberController.dispose();
    super.dispose();
  }

  // Format phone number as user types (XXX-XXX-XXXX format)
  void _formatPhoneNumber(TextEditingController controller) {
    final text = controller.text;
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length > 11) {
      controller.text = digits.substring(0, 11);
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
  }

  // Phone number validation method
  bool _validatePhoneNumber(String phone) {
    if (phone.isEmpty) return true; // Don't show error when empty

    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Must be exactly 11 digits
    if (digits.length != 11) {
      return false;
    }

    // Check if it's all digits
    if (!RegExp(r'^[0-9]{11}$').hasMatch(digits)) {
      return false;
    }

    // Validate Nigerian phone prefixes
    final validPrefixes = ['070', '080', '081', '090', '091'];
    final prefix = digits.substring(0, 3);

    if (!validPrefixes.contains(prefix)) {
      return false;
    }

    return true;
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff060121),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff060121),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final hour = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        controller.text = "$hour:$minute";
      });
    }
  }

  Future<void> _submitForm() async {
    if (_validateForm()) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xff060121)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Submitting Request...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff060121),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        // Get current user
        final user = _auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        // Clean phone numbers before saving
        final cleanPhone =
            phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
        final cleanContact =
            contactNumberController.text.replaceAll(RegExp(r'[^\d]'), '');

        // Use the ExeatService to create request
        await _exeatService.createRequest(
          destination: selectedDestination!,
          leaveDate: leaveDateController.text,
          returnDate: returnDateController.text,
          leaveTime: leaveTimeController.text,
          returnTime: returnTimeController.text,
          reason: reasonController.text,
          phone: cleanPhone,
          contactPerson: contactPersonController.text,
          contactNumber: cleanContact,
          guardianApproval: selectedApproval!,
          priorityLevel: selectedPriority!,
        );

        // Close loading dialog
        Navigator.of(context).pop();

        // Show success dialog
        _showSuccessDialog();
      } catch (e) {
        // Close loading dialog
        Navigator.of(context).pop();

        _showSnackBar('Error: $e');
      }
    }
  }

  bool _validateForm() {
    // Check all required fields
    if (selectedDestination == null ||
        leaveDateController.text.isEmpty ||
        leaveTimeController.text.isEmpty ||
        returnDateController.text.isEmpty ||
        returnTimeController.text.isEmpty ||
        reasonController.text.isEmpty ||
        contactPersonController.text.isEmpty ||
        selectedApproval == null) {
      _showSnackBar('Please fill in all required fields');
      return false;
    }

    // Get cleaned phone numbers (without dashes)
    final phoneDigits = phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    final contactDigits =
        contactNumberController.text.replaceAll(RegExp(r'[^\d]'), '');

    // Validate phone number length
    if (phoneDigits.length != 11) {
      _showSnackBar('Phone number must be exactly 11 digits');
      return false;
    }

    // Validate emergency contact number length
    if (contactDigits.length != 11) {
      _showSnackBar('Emergency contact number must be exactly 11 digits');
      return false;
    }

    // Validate phone number prefixes
    if (!_validatePhoneNumber(phoneController.text)) {
      _showSnackBar(
          'Invalid phone number. Must start with 070, 080, 081, 090, or 091');
      return false;
    }

    if (!_validatePhoneNumber(contactNumberController.text)) {
      _showSnackBar(
          'Invalid emergency contact. Must start with 070, 080, 081, 090, or 091');
      return false;
    }

    // Validate date logic
    final leaveDate = _parseDate(leaveDateController.text);
    final returnDate = _parseDate(returnDateController.text);

    if (leaveDate != null && returnDate != null) {
      if (returnDate.isBefore(leaveDate)) {
        _showSnackBar('Return date must be after leave date');
        return false;
      }

      // Check if dates are in the past
      if (leaveDate.isBefore(DateTime.now())) {
        _showSnackBar('Leave date cannot be in the past');
        return false;
      }
    }

    return true;
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [
                Color(0xff060121),
                Color(0xff2d1b5e),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'Request Submitted!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your exeat request has been submitted successfully\nand will appear in your request history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Get.to(() => const NewExeatForm());
                        },
                        child: const Text(
                          'NEW REQUEST',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Get.to(() => const HomePage());
                        },
                        child: const Text(
                          'BACK TO HOME',
                          style: TextStyle(
                            color: Color(0xff060121),
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    double containerWidth =
        screenWidth < 600 ? screenWidth * 0.9 : screenWidth * 0.4;
    double fontSizeTitle = screenWidth < 600 ? 28 : 36;
    double fontSizeSubtitle = screenWidth < 600 ? 14 : 16;
    double fontSizeButton = screenWidth < 600 ? 14 : 16;
    double paddingValue = screenWidth < 600 ? 16 : 24;

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
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: Container(
                  width: containerWidth,
                  margin: EdgeInsets.symmetric(vertical: paddingValue),
                  padding: EdgeInsets.all(paddingValue * 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with back button
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Get.back(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xff060121).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Color(0xff060121),
                                  size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "NEW EXEAT REQUEST",
                                  style: TextStyle(
                                    color: const Color(0xff060121),
                                    fontWeight: FontWeight.w900,
                                    fontSize: fontSizeTitle,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Fill in the details below to submit your exeat application",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: fontSizeSubtitle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Phone Number Field
                      _buildPhoneTextField(),
                      const SizedBox(height: 20),

                      // Destination Dropdown
                      _buildDestinationDropdown(),
                      const SizedBox(height: 20),

                      // Priority Dropdown
                      _buildPriorityDropdown(),
                      const SizedBox(height: 20),

                      // Date and Time Row
                      const Text(
                        "DEPARTURE",
                        style: TextStyle(
                          color: Color(0xff060121),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (screenWidth < 500) ...[
                        _buildDateTimeField(
                          hint: "SELECT DATE",
                          controller: leaveDateController,
                          onTap: () => _selectDate(leaveDateController),
                          icon: Icons.calendar_today_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildDateTimeField(
                          hint: "SELECT TIME",
                          controller: leaveTimeController,
                          onTap: () => _selectTime(leaveTimeController),
                          icon: Icons.access_time_rounded,
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateTimeField(
                                hint: "SELECT DATE",
                                controller: leaveDateController,
                                onTap: () => _selectDate(leaveDateController),
                                icon: Icons.calendar_today_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateTimeField(
                                hint: "SELECT TIME",
                                controller: leaveTimeController,
                                onTap: () => _selectTime(leaveTimeController),
                                icon: Icons.access_time_rounded,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),

                      // Return Date and Time
                      const Text(
                        "RETURN",
                        style: TextStyle(
                          color: Color(0xff060121),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (screenWidth < 500) ...[
                        _buildDateTimeField(
                          hint: "SELECT DATE",
                          controller: returnDateController,
                          onTap: () => _selectDate(returnDateController),
                          icon: Icons.calendar_today_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildDateTimeField(
                          hint: "SELECT TIME",
                          controller: returnTimeController,
                          onTap: () => _selectTime(returnTimeController),
                          icon: Icons.access_time_rounded,
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateTimeField(
                                hint: "SELECT DATE",
                                controller: returnDateController,
                                onTap: () => _selectDate(returnDateController),
                                icon: Icons.calendar_today_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateTimeField(
                                hint: "SELECT TIME",
                                controller: returnTimeController,
                                onTap: () => _selectTime(returnTimeController),
                                icon: Icons.access_time_rounded,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        "REASON FOR EXEAT",
                        controller: reasonController,
                        icon: Icons.description_rounded,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        "EMERGENCY CONTACT PERSON",
                        controller: contactPersonController,
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 20),

                      // Emergency Contact Number Field
                      _buildEmergencyContactField(),
                      const SizedBox(height: 20),

                      // Guardian Approval Dropdown
                      _buildGuardianDropdown(),
                      const SizedBox(height: 32),

                      // Submit Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: _isSubmitting
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xff060121),
                                    Color(0xff2d1b5e),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isSubmitting
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xff060121)
                                        .withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isSubmitting ? null : _submitForm,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: paddingValue * 0.9,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isSubmitting)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isSubmitting
                                        ? "SUBMITTING..."
                                        : "SUBMIT REQUEST",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: fontSizeButton + 2,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneTextField() {
    final digits = phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    final isValid = _validatePhoneNumber(phoneController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "PHONE NUMBER",
              style: TextStyle(
                color: Color(0xff060121),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              "(11 digits)",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: phoneController.text.isEmpty
                  ? Colors.grey[300]!
                  : isValid
                      ? Colors.green
                      : Colors.red,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(
                  Icons.phone_rounded,
                  color: phoneController.text.isEmpty
                      ? const Color(0xff060121)
                      : isValid
                          ? Colors.green
                          : Colors.red,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 13, // Account for dashes: XXX-XXX-XXXX
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: "080-123-45678",
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    counterText: "${digits.length}/11",
                    counterStyle: TextStyle(
                      color: digits.length == 11
                          ? Colors.green
                          : digits.isEmpty
                              ? Colors.grey
                              : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (phoneController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(
                    isValid ? Icons.check_circle : Icons.error,
                    color: isValid ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
        // Validation message
        if (phoneController.text.isNotEmpty && !isValid)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(
              digits.length < 11
                  ? "Phone number must be 11 digits"
                  : "Phone number must start with 070, 080, 081, 090, or 091",
              style: TextStyle(
                color: Colors.red[600],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmergencyContactField() {
    final digits =
        contactNumberController.text.replaceAll(RegExp(r'[^\d]'), '');
    final isValid = _validatePhoneNumber(contactNumberController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "EMERGENCY CONTACT NUMBER",
              style: TextStyle(
                color: Color(0xff060121),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              "(11 digits)",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: contactNumberController.text.isEmpty
                  ? Colors.grey[300]!
                  : isValid
                      ? Colors.green
                      : Colors.red,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(
                  Icons.contact_phone_rounded,
                  color: contactNumberController.text.isEmpty
                      ? const Color(0xff060121)
                      : isValid
                          ? Colors.green
                          : Colors.red,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: contactNumberController,
                  keyboardType: TextInputType.phone,
                  maxLength: 13, // Account for dashes: XXX-XXX-XXXX
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: "080-987-65432",
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    counterText: "${digits.length}/11",
                    counterStyle: TextStyle(
                      color: digits.length == 11
                          ? Colors.green
                          : digits.isEmpty
                              ? Colors.grey
                              : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (contactNumberController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(
                    isValid ? Icons.check_circle : Icons.error,
                    color: isValid ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
        // Validation message
        if (contactNumberController.text.isNotEmpty && !isValid)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(
              digits.length < 11
                  ? "Emergency contact must be 11 digits"
                  : "Emergency contact must start with 070, 080, 081, 090, or 091",
              style: TextStyle(
                color: Colors.red[600],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(
    String hint, {
    required TextEditingController controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: const Color(0xff060121)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeField({
    required String hint,
    required TextEditingController controller,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: const Color(0xff060121)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedDestination,
          isExpanded: true,
          hint: Text(
            "SELECT DESTINATION",
            style: TextStyle(
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down_rounded,
              color: Color(0xff060121)),
          items: destinations.map((String destination) {
            return DropdownMenuItem<String>(
              value: destination,
              child: Text(
                destination,
                style: const TextStyle(
                  color: Color(0xff060121),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedDestination = newValue;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedPriority,
          isExpanded: true,
          hint: Text(
            "SELECT PRIORITY LEVEL",
            style: TextStyle(
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          icon:
              const Icon(Icons.priority_high_rounded, color: Color(0xff060121)),
          items: priorities.map((String priority) {
            Color color = Colors.grey;
            IconData icon = Icons.circle;

            switch (priority) {
              case 'EMERGENCY':
                color = Colors.red;
                icon = Icons.emergency;
                break;
              case 'MEDICAL':
                color = Colors.orange;
                icon = Icons.medical_services;
                break;
              case 'FAMILY':
                color = Colors.blue;
                icon = Icons.family_restroom;
                break;
              case 'NORMAL':
                color = Colors.green;
                icon = Icons.auto_fix_normal;
                break;
            }

            return DropdownMenuItem<String>(
              value: priority,
              child: Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    priority,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedPriority = newValue;
            });
          },
        ),
      ),
    );
  }

  Widget _buildGuardianDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedApproval,
          isExpanded: true,
          hint: Text(
            "GUARDIAN APPROVAL STATUS",
            style: TextStyle(
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down_rounded,
              color: Color(0xff060121)),
          items: approval.map((String approval) {
            Color color = Colors.grey;
            IconData icon = Icons.circle;

            switch (approval) {
              case 'APPROVED':
                color = Colors.green;
                icon = Icons.check_circle;
                break;
              case 'PENDING':
                color = Colors.orange;
                icon = Icons.pending;
                break;
              case 'DECLINED':
                color = Colors.red;
                icon = Icons.cancel;
                break;
            }

            return DropdownMenuItem<String>(
              value: approval,
              child: Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    approval,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedApproval = newValue;
            });
          },
        ),
      ),
    );
  }
}
