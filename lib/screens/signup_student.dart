import 'package:exeat_system/screens/login_screen__student.dart';
import 'package:exeat_system/screens/signup_staff.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> with TickerProviderStateMixin {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? selectedHostel;
  String? selectedDepartment;

  final List<Map<String, String>> departments = [
    {'id': 'computer_science', 'name': 'Computer Science'},
    {'id': 'criminology', 'name': 'Criminology'},
    {'id': 'mass_communication', 'name': 'Mass Communication'},
    {'id': 'management_science', 'name': 'Management Science'},
    {'id': 'allied_sciences', 'name': 'Allied Sciences'},
    {
      'id': 'biological_chemical_sciences',
      'name': 'Biological and Chemical Sciences'
    },
  ];

  final List<Map<String, String>> halls = [
    {'id': 'bishop', 'name': 'Bishop Hall'},
    {'id': 'rehoboth', 'name': 'Rehoboth Hall'},
    {'id': 'new', 'name': 'New Hall'},
    {'id': 'victory', 'name': 'Victory Hall'},
    {'id': 'faith', 'name': 'Faith Hall'},
    {'id': 'landmark', 'name': 'Landmark Hall'},
  ];

  // Form controllers & key
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _matricController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // Animations
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isStudent = true;
  bool _isLoading = false;
  bool _isVerifying = false;
  bool _allocationFound = false;
  String _verificationStatus = '';

  // Detail matching validation
  Map<String, dynamic>? _allocationData;
  bool _detailsMatch = false;
  String _mismatchErrors = '';

  bool get canSubmit => _allocationFound && _detailsMatch && !_isLoading;

  // Phone validation
  String _phoneError = '';
  final List<String> _validPrefixes = ['070', '080', '081', '090', '091'];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    // Add listener for phone formatting
    _phoneController.addListener(_formatPhoneNumber);

    // Add listeners for detail validation
    _fullNameController.addListener(_validateAllocationDetails);
    _emailController.addListener(_validateAllocationDetails);
    _phoneController.addListener(_validateAllocationDetails);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _matricController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Format phone number as user types
  void _formatPhoneNumber() {
    final text = _phoneController.text;
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length > 11) {
      _phoneController.text = digits.substring(0, 11);
      _phoneController.selection = TextSelection.fromPosition(
        TextPosition(offset: _phoneController.text.length),
      );
    }

    // Validate phone number
    _validatePhoneNumber();
  }

  // Validate phone number
  void _validatePhoneNumber() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      _phoneError = '';
    } else if (digits.length != 11) {
      _phoneError = 'Phone number must be exactly 11 digits';
    } else {
      final prefix = digits.substring(0, 3);
      if (!_validPrefixes.contains(prefix)) {
        _phoneError = 'Must start with 070, 080, 081, 090, or 091';
      } else {
        _phoneError = '';
      }
    }

    setState(() {});
  }

  // Check if student is allocated
  Future<void> _checkAllocation() async {
    final matricNumber = _matricController.text.trim();

    if (matricNumber.isEmpty) {
      setState(() {
        _allocationFound = false;
        _verificationStatus = '';
        _allocationData = null;
        _detailsMatch = false;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationStatus = 'Checking allocation...';
      _mismatchErrors = '';
      _detailsMatch = false;
    });

    try {
      // Check if student exists in allocated_students collection
      final allocationDoc = await _firestore
          .collection('allocated_students')
          .doc(matricNumber.toLowerCase())
          .get();

      if (allocationDoc.exists) {
        // Check if already registered
        final data = allocationDoc.data()!;
        if (data['isRegistered'] == true) {
          setState(() {
            _isVerifying = false;
            _allocationFound = false;
            _verificationStatus = '❌ This student is already registered';
            _allocationData = null;
          });
        } else {
          setState(() {
            _isVerifying = false;
            _allocationFound = true;
            _allocationData = data;
            _verificationStatus = '✅ Student is allocated';
          });

          // Auto-fill data if available
          _autoFillFromAllocation(data);
        }
      } else {
        setState(() {
          _isVerifying = false;
          _allocationFound = false;
          _verificationStatus =
              '❌ Student not allocated. Contact administration.';
          _allocationData = null;
        });
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _allocationFound = false;
        _verificationStatus = 'Error checking allocation';
        _allocationData = null;
      });
    }
  }

  // Auto-fill fields from allocation data
  void _autoFillFromAllocation(Map<String, dynamic> data) {
    print('=== AUTO-FILL DEBUG ===');
    print('Allocation data: $data');

    // Auto-fill fields if they exist in allocation data
    if (data['fullName'] != null && _fullNameController.text.isEmpty) {
      _fullNameController.text = data['fullName'];
      print('Auto-filled name: ${data['fullName']}');
    }

    if (data['email'] != null && _emailController.text.isEmpty) {
      _emailController.text = data['email'];
      print('Auto-filled email: ${data['email']}');
    }

    if (data['phone'] != null && _phoneController.text.isEmpty) {
      _phoneController.text = data['phone'];
      print('Auto-filled phone: ${data['phone']}');
    }

    // Try to set department from various field names
    if (selectedDepartment == null) {
      String? deptToSet;

      if (data['departmentId'] != null) {
        deptToSet = data['departmentId'].toString();
        print('Found departmentId: $deptToSet');
      } else if (data['department'] != null) {
        final deptName = data['department'].toString();
        print('Looking for department by name: $deptName');

        // Try to find department ID from name
        for (var dept in departments) {
          if (dept['name']!.toLowerCase() == deptName.toLowerCase() ||
              deptName.toLowerCase().contains(dept['name']!.toLowerCase()) ||
              dept['name']!.toLowerCase().contains(deptName.toLowerCase())) {
            deptToSet = dept['id'];
            print(
                'Found matching department: ${dept['name']} -> ${dept['id']}');
            break;
          }
        }
      } else if (data['departmentName'] != null) {
        final deptName = data['departmentName'].toString();
        print('Looking for department by departmentName: $deptName');

        for (var dept in departments) {
          if (dept['name']!.toLowerCase() == deptName.toLowerCase() ||
              deptName.toLowerCase().contains(dept['name']!.toLowerCase()) ||
              dept['name']!.toLowerCase().contains(deptName.toLowerCase())) {
            deptToSet = dept['id'];
            print(
                'Found matching department: ${dept['name']} -> ${dept['id']}');
            break;
          }
        }
      }

      if (deptToSet != null) {
        selectedDepartment = deptToSet;
        print('Auto-selected department: $deptToSet');
      }
    }

    // Try to set hall from various field names
    if (selectedHostel == null) {
      String? hallToSet;

      if (data['hallId'] != null) {
        hallToSet = data['hallId'].toString();
        print('Found hallId: $hallToSet');
      } else if (data['hall'] != null) {
        final hallName = data['hall'].toString();
        print('Looking for hall by name: $hallName');

        // Try to find hall ID from name
        for (var hall in halls) {
          if (hall['name']!.toLowerCase() == hallName.toLowerCase() ||
              hallName.toLowerCase().contains(hall['name']!.toLowerCase()) ||
              hall['name']!.toLowerCase().contains(hallName.toLowerCase())) {
            hallToSet = hall['id'];
            print('Found matching hall: ${hall['name']} -> ${hall['id']}');
            break;
          }
        }
      } else if (data['hallName'] != null) {
        final hallName = data['hallName'].toString();
        print('Looking for hall by hallName: $hallName');

        for (var hall in halls) {
          if (hall['name']!.toLowerCase() == hallName.toLowerCase() ||
              hallName.toLowerCase().contains(hall['name']!.toLowerCase()) ||
              hall['name']!.toLowerCase().contains(hallName.toLowerCase())) {
            hallToSet = hall['id'];
            print('Found matching hall: ${hall['name']} -> ${hall['id']}');
            break;
          }
        }
      }

      if (hallToSet != null) {
        selectedHostel = hallToSet;
        print('Auto-selected hall: $hallToSet');
      }
    }

    print('Final selected department: $selectedDepartment');
    print('Final selected hostel: $selectedHostel');
    print('=== END AUTO-FILL DEBUG ===');

    // Validate details after auto-fill
    _validateAllocationDetails();
    setState(() {});
  }

  // Validate entered details against allocation data
  void _validateAllocationDetails() {
    if (_allocationData == null || !_allocationFound) {
      setState(() {
        _detailsMatch = false;
        _mismatchErrors = '';
      });
      return;
    }

    final errors = <String>[];
    final allocation = _allocationData!;

    // Debug: Print allocation data to see what we're comparing
    print('=== VALIDATION DEBUG ===');
    print('Allocation data: $allocation');
    print('Selected Department: $selectedDepartment');
    print('Selected Hostel: $selectedHostel');

    // Check full name
    final allocatedName =
        (allocation['fullName'] ?? '').toString().trim().toLowerCase();
    final enteredName = _fullNameController.text.trim().toLowerCase();
    if (allocatedName.isNotEmpty && allocatedName != enteredName) {
      errors
          .add('Name does not match allocated name: ${allocation['fullName']}');
      print('Name mismatch: $allocatedName vs $enteredName');
    }

    // Check department - FIRST check if we even need to validate department
    bool departmentNeedsValidation = true;
    String allocatedDept = '';

    // Get department from allocation (could be ID or name)
    if (allocation['departmentId'] != null) {
      allocatedDept = allocation['departmentId'].toString();
      print('Allocated departmentId: $allocatedDept');
    } else if (allocation['department'] != null) {
      allocatedDept = allocation['department'].toString();
      print('Allocated department: $allocatedDept');
    } else if (allocation['departmentName'] != null) {
      allocatedDept = allocation['departmentName'].toString();
      print('Allocated departmentName: $allocatedDept');
    } else {
      // No department info in allocation, skip validation
      departmentNeedsValidation = false;
      print('No department info in allocation');
    }

    if (departmentNeedsValidation && selectedDepartment != null) {
      bool departmentMatches = false;

      // Try exact ID match first
      if (allocatedDept == selectedDepartment) {
        departmentMatches = true;
        print(
            'Department exact ID match: $allocatedDept == $selectedDepartment');
      }
      // Try to find if allocatedDept is a name that matches any department
      else {
        // Check if allocatedDept is a department name (not ID)
        for (var dept in departments) {
          if (dept['name']!.toLowerCase() == allocatedDept.toLowerCase()) {
            // Allocated data has department NAME, compare with selected ID
            if (dept['id'] == selectedDepartment) {
              departmentMatches = true;
              print(
                  'Department name->ID match: ${dept['name']} -> ${dept['id']}');
            }
            break;
          }
        }

        // If still no match, try partial name matching
        if (!departmentMatches) {
          for (var dept in departments) {
            if (allocatedDept
                    .toLowerCase()
                    .contains(dept['name']!.toLowerCase()) ||
                dept['name']!
                    .toLowerCase()
                    .contains(allocatedDept.toLowerCase())) {
              if (dept['id'] == selectedDepartment) {
                departmentMatches = true;
                print(
                    'Department partial name match: $allocatedDept contains ${dept['name']}');
              }
            }
          }
        }
      }

      if (!departmentMatches) {
        // Find the department name for error message
        String deptName = 'Unknown';
        for (var dept in departments) {
          if (dept['id'] == selectedDepartment) {
            deptName = dept['name']!;
            break;
          }
        }
        errors.add(
            'Department should be: $allocatedDept (You selected: $deptName)');
      }
    }

    // Check hall - FIRST check if we even need to validate hall
    bool hallNeedsValidation = true;
    String allocatedHall = '';

    // Get hall from allocation (could be ID or name)
    if (allocation['hallId'] != null) {
      allocatedHall = allocation['hallId'].toString();
      print('Allocated hallId: $allocatedHall');
    } else if (allocation['hall'] != null) {
      allocatedHall = allocation['hall'].toString();
      print('Allocated hall: $allocatedHall');
    } else if (allocation['hallName'] != null) {
      allocatedHall = allocation['hallName'].toString();
      print('Allocated hallName: $allocatedHall');
    } else {
      // No hall info in allocation, skip validation
      hallNeedsValidation = false;
      print('No hall info in allocation');
    }

    if (hallNeedsValidation && selectedHostel != null) {
      bool hallMatches = false;

      // Try exact ID match first
      if (allocatedHall == selectedHostel) {
        hallMatches = true;
        print('Hall exact ID match: $allocatedHall == $selectedHostel');
      }
      // Try to find if allocatedHall is a name that matches any hall
      else {
        // Check if allocatedHall is a hall name (not ID)
        for (var hall in halls) {
          if (hall['name']!.toLowerCase() == allocatedHall.toLowerCase()) {
            // Allocated data has hall NAME, compare with selected ID
            if (hall['id'] == selectedHostel) {
              hallMatches = true;
              print('Hall name->ID match: ${hall['name']} -> ${hall['id']}');
            }
            break;
          }
        }

        // If still no match, try partial name matching
        if (!hallMatches) {
          for (var hall in halls) {
            if (allocatedHall
                    .toLowerCase()
                    .contains(hall['name']!.toLowerCase()) ||
                hall['name']!
                    .toLowerCase()
                    .contains(allocatedHall.toLowerCase())) {
              if (hall['id'] == selectedHostel) {
                hallMatches = true;
                print(
                    'Hall partial name match: $allocatedHall contains ${hall['name']}');
              }
            }
          }
        }
      }

      if (!hallMatches) {
        // Find the hall name for error message
        String hallName = 'Unknown';
        for (var hall in halls) {
          if (hall['id'] == selectedHostel) {
            hallName = hall['name']!;
            break;
          }
        }
        errors.add('Hall should be: $allocatedHall (You selected: $hallName)');
      }
    }

    // Check email (if provided in allocation)
    final allocatedEmail =
        (allocation['email'] ?? '').toString().trim().toLowerCase();
    final enteredEmail = _emailController.text.trim().toLowerCase();
    if (allocatedEmail.isNotEmpty && allocatedEmail != enteredEmail) {
      errors
          .add('Email does not match allocated email: ${allocation['email']}');
    }

    // Check phone (if provided in allocation)
    final allocatedPhone = (allocation['phone'] ?? '').toString().trim();
    final enteredPhone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (allocatedPhone.isNotEmpty && allocatedPhone != enteredPhone) {
      errors
          .add('Phone does not match allocated phone: ${allocation['phone']}');
    }

    // Also check matric number for consistency
    final allocatedMatric =
        (allocation['matricNumber'] ?? allocation['matricNo'] ?? '')
            .toString()
            .toLowerCase();
    final enteredMatric = _matricController.text.trim().toLowerCase();
    if (allocatedMatric.isNotEmpty && allocatedMatric != enteredMatric) {
      errors.add(
          'Matric number does not match allocated: ${allocation['matricNumber'] ?? allocation['matricNo']}');
    }

    print('Validation errors: $errors');
    print('Details match: ${errors.isEmpty}');
    print('=== END DEBUG ===');

    setState(() {
      _mismatchErrors = errors.join('\n');
      _detailsMatch = errors.isEmpty;
    });
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if student is allocated
    if (!_allocationFound) {
      Get.snackbar(
        "Registration Denied",
        "Student is not allocated. Please contact administration.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      return;
    }

    // Check if details match allocation
    if (!_detailsMatch) {
      Get.snackbar(
        "Details Mismatch",
        "Your entered details do not match the allocation data. Please correct them.",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      return;
    }

    // Validate required fields
    if (selectedDepartment == null || selectedDepartment!.isEmpty) {
      Get.snackbar(
        "Error",
        "Please select your department",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (selectedHostel == null || selectedHostel!.isEmpty) {
      Get.snackbar(
        "Error",
        "Please select your hostel",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Final phone validation
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (phoneDigits.length != 11) {
      Get.snackbar(
        "Error",
        "Phone number must be exactly 11 digits",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final prefix = phoneDigits.substring(0, 3);
    if (!_validPrefixes.contains(prefix)) {
      Get.snackbar(
        "Error",
        "Phone number must start with 070, 080, 081, 090, or 091",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      Get.snackbar(
        "Error",
        "Passwords do not match",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user!;

      // 2. Mark student as registered in allocated_students
      final matricNumber = _matricController.text.trim().toLowerCase();
      await _firestore
          .collection('allocated_students')
          .doc(matricNumber)
          .update({
        'isRegistered': true,
        'registeredAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });

      // 3. Find department and hall details
      final department = departments.firstWhere(
        (dept) => dept['id'] == selectedDepartment,
        orElse: () => {'id': '', 'name': ''},
      );

      final hall = halls.firstWhere(
        (h) => h['id'] == selectedHostel,
        orElse: () => {'id': '', 'name': ''},
      );

      // 4. Create student document in Firestore
      await _firestore.collection('students').doc(user.uid).set({
        'studentId': user.uid,
        'uid': user.uid,
        'name': _fullNameController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'matricNumber': _matricController.text.trim(),
        'matricNo': _matricController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': phoneDigits,
        'department': department['name'] ?? '',
        'departmentId': selectedDepartment,
        'departmentName': department['name'] ?? '',
        'hall': hall['name'] ?? '',
        'hallId': selectedHostel,
        'hallName': hall['name'] ?? '',
        'level': '400 Level',
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isAllocated': true, // Flag to show student is allocated
        'profileImage': '',
        'hasPendingRequest': false,
        'currentExeat': null,
        'exeatHistory': [],
      });

      Get.snackbar(
        "Success",
        "Account created successfully!",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );

      // Delay navigation to show success message
      await Future.delayed(const Duration(seconds: 2));

      Get.offAll(() => const LoginScreen());
    } on FirebaseAuthException catch (e) {
      String message = "Signup failed";
      if (e.code == 'email-already-in-use') {
        message = "Email already registered";
      } else if (e.code == 'weak-password') {
        message = "Password is too weak (minimum 6 characters)";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email address";
      }

      Get.snackbar(
        "Error",
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Signup failed: ${e.toString()}",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    double containerWidth =
        screenWidth < 600 ? screenWidth * 0.9 : screenWidth * 0.4;
    double fontSizeTitle = screenWidth < 600 ? 28 : 36;
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
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Icon badge (matches login style)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xff060121),
                                Color(0xff2d1b5e),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xff060121).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Title
                        Center(
                          child: Text(
                            "STUDENT REGISTRATION",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xff060121),
                              fontWeight: FontWeight.w900,
                              fontSize: fontSizeTitle,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle - Centered
                        Center(
                          child: Text(
                            "For allocated students only",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: fontSizeButton,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Tab Selector (Student / Admin)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTabButton(
                                  "Student",
                                  _isStudent,
                                  () {
                                    setState(() {
                                      _isStudent = true;
                                    });
                                  },
                                ),
                              ),
                              Expanded(
                                child: _buildTabButton(
                                  "Admin",
                                  !_isStudent,
                                  () {
                                    setState(() {
                                      _isStudent = false;
                                    });
                                    Get.to(() => const SignupStaff());
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Matric number with verification button
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    hintText: 'Matric number*',
                                    icon: Icons.badge,
                                    controller: _matricController,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your matric number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: _checkAllocation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xff060121),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 16),
                                  ),
                                  child: _isVerifying
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Text('Check'),
                                ),
                              ],
                            ),
                            if (_verificationStatus.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8, left: 8),
                                child: Text(
                                  _verificationStatus,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _allocationFound
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Detail Matching Validation Display
                        if (_allocationFound && _allocationData != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _detailsMatch
                                  ? Colors.green[50]
                                  : Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _detailsMatch
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _detailsMatch
                                          ? Icons.check_circle
                                          : Icons.warning,
                                      color: _detailsMatch
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _detailsMatch
                                          ? 'Details match allocation'
                                          : 'Verify your details',
                                      style: TextStyle(
                                        color: _detailsMatch
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_mismatchErrors.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _mismatchErrors,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                        // Full Name
                        _buildInputField(
                          hintText: 'Full Name*',
                          icon: Icons.person,
                          controller: _fullNameController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Phone Number with validation
                        _buildPhoneNumberField(),
                        const SizedBox(height: 20),

                        // Department Dropdown
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey[300]!, width: 1.5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              prefixIcon:
                                  Icon(Icons.school, color: Color(0xff060121)),
                              hintText: "Select Your Department*",
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            items: departments.map((Map<String, String> dept) {
                              return DropdownMenuItem<String>(
                                value: dept['id'],
                                child: Text(dept['name']!),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedDepartment = newValue;
                              });
                              // Force validation immediately after UI update
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _validateAllocationDetails();
                                setState(() {});
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your department';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Email
                        _buildInputField(
                          hintText: 'Email*',
                          icon: Icons.email,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Hostel Dropdown
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey[300]!, width: 1.5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonFormField<String>(
                            value: selectedHostel,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              prefixIcon:
                                  Icon(Icons.home, color: Color(0xff060121)),
                              hintText: "Select Your Hostel*",
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            items: halls.map((Map<String, String> hall) {
                              return DropdownMenuItem<String>(
                                value: hall['id'],
                                child: Text(hall['name']!),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedHostel = newValue;
                              });
                              // Force validation immediately after UI update
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _validateAllocationDetails();
                                setState(() {});
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your hostel';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Password
                        _buildPasswordField(
                          controller: _passwordController,
                          hintText: 'Create Password*',
                          isPassword: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Confirm Password
                        _buildPasswordField(
                          controller: _confirmController,
                          hintText: 'Confirm Password*',
                          isPassword: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleSignUp(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),

                        // Sign Up Button
                        _buildActionButton(paddingValue, fontSizeButton),
                        const SizedBox(height: 20),

                        // Already have account -> login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: TextStyle(
                                fontSize: fontSizeButton,
                                color: Colors.grey[700],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Get.to(() => const LoginScreen());
                              },
                              child: Text(
                                "Log In",
                                style: TextStyle(
                                  fontSize: fontSizeButton,
                                  color: const Color(0xff060121),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
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
          ),
        ),
      ),
    );
  }

  // Phone Number Field with Validation
  Widget _buildPhoneNumberField() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    final isValid =
        digits.length == 11 && _validPrefixes.contains(digits.substring(0, 3));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Phone Number*",
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
              color: _phoneController.text.isEmpty
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
                  color: _phoneController.text.isEmpty
                      ? const Color(0xff060121)
                      : isValid
                          ? Colors.green
                          : Colors.red,
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: "08012345678",
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
                    errorText: _phoneError.isNotEmpty ? _phoneError : null,
                    errorStyle: const TextStyle(height: 0.8, fontSize: 12),
                  ),
                ),
              ),
              if (_phoneController.text.isNotEmpty)
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
      ],
    );
  }

  // Reusable widgets

  Widget _buildTabButton(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: isActive
                  ? const LinearGradient(
                      colors: [
                        Color(0xff060121),
                        Color(0xff2d1b5e),
                      ],
                    )
                  : null,
              color: isActive ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xff060121).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            )));
  }

  Widget _buildInputField({
    required String hintText,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType ?? TextInputType.text,
        inputFormatters: inputFormatters,
        textInputAction: textInputAction ?? TextInputAction.next,
        onFieldSubmitted: onFieldSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: const Color(0xff060121)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          errorStyle: const TextStyle(height: 0.8, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool isPassword,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : _obscureConfirmPassword,
        validator: validator,
        textInputAction: textInputAction ?? TextInputAction.next,
        onFieldSubmitted: onFieldSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon:
              const Icon(Icons.lock_outline_rounded, color: Color(0xff060121)),
          suffixIcon: IconButton(
            icon: Icon(
              isPassword
                  ? (_obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded)
                  : (_obscureConfirmPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
              color: Colors.grey[600],
            ),
            onPressed: () {
              setState(() {
                if (isPassword) {
                  _obscurePassword = !_obscurePassword;
                } else {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                }
              });
            },
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          errorStyle: const TextStyle(height: 0.8, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildActionButton(double paddingValue, double fontSizeButton) {
    final bool isActive = (_allocationFound && _detailsMatch) || _isLoading;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [
                  Color(0xff060121),
                  Color(0xff2d1b5e),
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.grey[400]!,
                  Colors.grey[600]!,
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xff060121).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSubmit ? _handleSignUp : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: paddingValue * 0.9),
            child: Center(
              child: _isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "SIGNING UP...",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: fontSizeButton + 2,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      !_allocationFound
                          ? "VERIFY MATRIC FIRST"
                          : !_detailsMatch
                              ? "FIX DETAILS TO CONTINUE"
                              : "SIGN UP",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: fontSizeButton + 2,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
