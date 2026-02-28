import 'package:exeat_system/screens/loginscreen_staff.dart';
import 'package:exeat_system/screens/signup_student.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SignupStaff extends StatefulWidget {
  const SignupStaff({super.key});

  @override
  State<SignupStaff> createState() => _SignupStaffState();
}

class _SignupStaffState extends State<SignupStaff>
    with TickerProviderStateMixin {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _staffIdController = TextEditingController();
  final _phoneController = TextEditingController();

  String? selectedRole = 'HOD';
  final List<String> roles = [
    'HOD',
    'STUDENT_AFFAIRS',
    'HALL_WARDEN',
    'SUPER_ADMIN'
  ];

  // Department and Hall selection
  String? selectedDepartment;
  String? selectedHall;

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

  bool _isStudent = false;
  bool _isLoading = false;
  bool _isVerifying = false;
  bool _allocationFound = false;
  String _verificationStatus = '';

  // Detail matching validation
  Map<String, dynamic>? _allocationData;
  bool _detailsMatch = false;
  String _mismatchErrors = '';

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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _fullNameController.dispose();
    _staffIdController.dispose();
    _phoneController.dispose();
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

  // Check if staff is allocated
  Future<void> _checkAllocation() async {
    final staffId = _staffIdController.text.trim();

    if (staffId.isEmpty) {
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
      // Check if staff exists in allocated_admins collection
      final allocationDoc = await _firestore
          .collection('allocated_admins')
          .doc(staffId.toLowerCase())
          .get();

      if (allocationDoc.exists) {
        final data = allocationDoc.data()!;

        // Check role compatibility
        final allocatedRole = data['role'] ?? '';
        final requestedRole = selectedRole ?? 'HOD';

        // Convert to comparable formats
        final allocatedRoleLower =
            allocatedRole.toString().toLowerCase().replaceAll('_', ' ');
        final requestedRoleLower =
            requestedRole.toLowerCase().replaceAll('_', ' ');

        bool roleMatches = false;

        // Check for role matches (allow some flexibility)
        if (allocatedRoleLower.contains('hod') &&
            requestedRoleLower.contains('hod')) {
          roleMatches = true;
        } else if (allocatedRoleLower.contains('student affairs') &&
            requestedRoleLower.contains('student_affairs')) {
          roleMatches = true;
        } else if (allocatedRoleLower.contains('warden') &&
            requestedRoleLower.contains('hall_warden')) {
          roleMatches = true;
        } else if (allocatedRoleLower.contains('super admin') &&
            requestedRoleLower.contains('super_admin')) {
          roleMatches = true;
        } else if (allocatedRoleLower == requestedRoleLower) {
          roleMatches = true;
        }

        if (!roleMatches) {
          setState(() {
            _isVerifying = false;
            _allocationFound = false;
            _verificationStatus =
                '❌ Staff ID allocated for different role: $allocatedRole';
            _allocationData = null;
          });
          return;
        }

        // Check if already registered
        if (data['isRegistered'] == true) {
          setState(() {
            _isVerifying = false;
            _allocationFound = false;
            _verificationStatus = '❌ This staff is already registered';
            _allocationData = null;
          });
        } else {
          setState(() {
            _isVerifying = false;
            _allocationFound = true;
            _allocationData = data;
            _verificationStatus = '✅ Staff is allocated';
          });

          // Auto-fill data if available
          _autoFillFromAllocation(data);
        }
      } else {
        setState(() {
          _isVerifying = false;
          _allocationFound = false;
          _verificationStatus =
              '❌ Staff not allocated. Contact administration.';
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
    print('=== STAFF AUTO-FILL DEBUG ===');
    print('Allocation data: $data');

    // Auto-fill data if available
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

    // Auto-select department for HOD
    final requestedRoleLower =
        (selectedRole ?? 'HOD').toLowerCase().replaceAll('_', ' ');
    if (requestedRoleLower.contains('hod') && selectedDepartment == null) {
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

    // Auto-select hall for HALL_WARDEN
    if (requestedRoleLower.contains('warden') && selectedHall == null) {
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
        selectedHall = hallToSet;
        print('Auto-selected hall: $hallToSet');
      }
    }

    print('Final selected role: $selectedRole');
    print('Final selected department: $selectedDepartment');
    print('Final selected hall: $selectedHall');
    print('=== END STAFF AUTO-FILL DEBUG ===');

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
    print('=== STAFF VALIDATION DEBUG ===');
    print('Allocation data: $allocation');
    print('Selected Role: $selectedRole');
    print('Selected Department: $selectedDepartment');
    print('Selected Hall: $selectedHall');

    // Check full name
    final allocatedName =
        (allocation['fullName'] ?? '').toString().trim().toLowerCase();
    final enteredName = _fullNameController.text.trim().toLowerCase();
    if (allocatedName.isNotEmpty && allocatedName != enteredName) {
      errors
          .add('Name does not match allocated name: ${allocation['fullName']}');
      print('Name mismatch: $allocatedName vs $enteredName');
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

    // Check staff ID for consistency
    final allocatedStaffId =
        (allocation['staffId'] ?? '').toString().toLowerCase();
    final enteredStaffId = _staffIdController.text.trim().toLowerCase();
    if (allocatedStaffId.isNotEmpty && allocatedStaffId != enteredStaffId) {
      errors.add('Staff ID does not match allocated: ${allocation['staffId']}');
    }

    // Check department for HOD
    final requestedRoleLower =
        (selectedRole ?? 'HOD').toLowerCase().replaceAll('_', ' ');
    if (requestedRoleLower.contains('hod')) {
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
        print('No department info in allocation for HOD');
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
    }

    // Check hall for HALL_WARDEN
    if (requestedRoleLower.contains('warden')) {
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
        print('No hall info in allocation for HALL_WARDEN');
      }

      if (hallNeedsValidation && selectedHall != null) {
        bool hallMatches = false;

        // Try exact ID match first
        if (allocatedHall == selectedHall) {
          hallMatches = true;
          print('Hall exact ID match: $allocatedHall == $selectedHall');
        }
        // Try to find if allocatedHall is a name that matches any hall
        else {
          // Check if allocatedHall is a hall name (not ID)
          for (var hall in halls) {
            if (hall['name']!.toLowerCase() == allocatedHall.toLowerCase()) {
              // Allocated data has hall NAME, compare with selected ID
              if (hall['id'] == selectedHall) {
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
                if (hall['id'] == selectedHall) {
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
            if (hall['id'] == selectedHall) {
              hallName = hall['name']!;
              break;
            }
          }
          errors
              .add('Hall should be: $allocatedHall (You selected: $hallName)');
        }
      }
    }

    print('Staff validation errors: $errors');
    print('Staff details match: ${errors.isEmpty}');
    print('=== END STAFF DEBUG ===');

    setState(() {
      _mismatchErrors = errors.join('\n');
      _detailsMatch = errors.isEmpty;
    });
  }

  // Check if role requires department
  bool get _requiresDepartment {
    return selectedRole == 'HOD';
  }

  // Check if role requires hall
  bool get _requiresHall {
    return selectedRole == 'HALL_WARDEN';
  }

  // Format role name for display
  String _formatRoleName(String role) {
    return role.replaceAll('_', ' ');
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if staff is allocated
    if (!_allocationFound) {
      Get.snackbar(
        "Registration Denied",
        "Staff is not allocated. Please contact administration.",
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

    // Validate role-specific fields
    if (_requiresDepartment &&
        (selectedDepartment == null || selectedDepartment!.isEmpty)) {
      Get.snackbar(
        "Error",
        "Please select a department for HOD role",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_requiresHall && (selectedHall == null || selectedHall!.isEmpty)) {
      Get.snackbar(
        "Error",
        "Please select a hall for Hall Warden role",
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

      // 2. Mark staff as registered in allocated_admins
      final staffId = _staffIdController.text.trim().toLowerCase();
      await _firestore.collection('allocated_admins').doc(staffId).update({
        'isRegistered': true,
        'registeredAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });

      // 3. Create admin document in Firestore with dynamic fields
      Map<String, dynamic> adminData = {
        'adminId': user.uid,
        'uid': user.uid,
        'name': _fullNameController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'staffId': _staffIdController.text.trim(),
        'phone': phoneDigits,
        'role': (selectedRole ?? 'HOD').toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isAllocated': true, // Flag to show admin is allocated
        'profileImage': '',
      };

      // Add department or hall based on role
      if (_requiresDepartment) {
        // Find the department name
        final dept = departments.firstWhere(
          (dept) => dept['id'] == selectedDepartment,
          orElse: () => {'id': '', 'name': ''},
        );
        adminData['departmentId'] = selectedDepartment;
        adminData['departmentName'] = dept['name'];
        adminData['hallId'] = null;
        adminData['hallName'] = null;
      } else if (_requiresHall) {
        // Find the hall name
        final hall = halls.firstWhere(
          (hall) => hall['id'] == selectedHall,
          orElse: () => {'id': '', 'name': ''},
        );
        adminData['hallId'] = selectedHall;
        adminData['hallName'] = hall['name'];
        adminData['departmentId'] = null;
        adminData['departmentName'] = null;
      } else {
        // For STUDENT_AFFAIRS and SUPER_ADMIN, no department/hall needed
        adminData['departmentId'] = null;
        adminData['departmentName'] = null;
        adminData['hallId'] = null;
        adminData['hallName'] = null;
      }

      await _firestore.collection('admins').doc(user.uid).set(adminData);

      Get.snackbar(
        "Success",
        "${_formatRoleName(selectedRole!)} account created successfully!",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Delay navigation to show success message
      await Future.delayed(const Duration(seconds: 2));

      Get.offAll(() => const LoginscreenStaff());
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;

    double containerWidth =
        isSmallScreen ? screenWidth * 0.95 : screenWidth * 0.5;
    double containerMaxWidth = 500;
    if (containerWidth > containerMaxWidth) containerWidth = containerMaxWidth;

    double fontSizeTitle = isSmallScreen ? 26 : 32;
    double fontSizeButton = isSmallScreen ? 14 : 16;
    double paddingValue = isSmallScreen ? 16 : 24;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
                  margin: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 16 : 32,
                    horizontal: isSmallScreen ? 8 : 0,
                  ),
                  padding: EdgeInsets.all(paddingValue * 1.2),
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Admin Icon Badge - Centered
                        Center(
                          child: Container(
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
                                  color:
                                      const Color(0xff060121).withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title - Centered
                        Center(
                          child: Text(
                            "CREATE ADMIN ACCOUNT",
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
                            "For allocated staff only",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: fontSizeButton,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Tab Selector (Student / Admin) - Centered
                        Center(
                          child: Container(
                            width: double.infinity,
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
                                      Get.to(() => const Signup());
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
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

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

                        // Staff ID with verification button
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    hintText: 'Staff ID*',
                                    icon: Icons.badge,
                                    controller: _staffIdController,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your staff ID';
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

                        // Full Name Field
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

                        // Phone Number Field
                        _buildPhoneNumberField(),
                        const SizedBox(height: 20),

                        // Role Dropdown
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey[300]!, width: 1.5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonFormField<String>(
                            value: selectedRole,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              prefixIcon:
                                  Icon(Icons.work, color: Color(0xff060121)),
                              hintText: "Select Role*",
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            items: roles.map((String role) {
                              return DropdownMenuItem<String>(
                                value: role,
                                child: Text(
                                  _formatRoleName(role),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedRole = newValue;
                                // Clear previous selections when role changes
                                selectedDepartment = null;
                                selectedHall = null;
                              });
                              _validateAllocationDetails();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your role';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Department Dropdown (only for HOD)
                        if (_requiresDepartment) ...[
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
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8),
                                prefixIcon: Icon(Icons.school,
                                    color: Color(0xff060121)),
                                hintText: "Select Department*",
                              ),
                              icon: const Icon(Icons.arrow_drop_down),
                              isExpanded: true,
                              items:
                                  departments.map((Map<String, String> dept) {
                                return DropdownMenuItem<String>(
                                  value: dept['id'],
                                  child: Text(
                                    dept['name']!,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedDepartment = newValue;
                                });
                                _validateAllocationDetails();
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a department';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Hall Dropdown (only for HALL_WARDEN)
                        if (_requiresHall) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.grey[300]!, width: 1.5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonFormField<String>(
                              value: selectedHall,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8),
                                prefixIcon:
                                    Icon(Icons.house, color: Color(0xff060121)),
                                hintText: "Select Hall*",
                              ),
                              icon: const Icon(Icons.arrow_drop_down),
                              isExpanded: true,
                              items: halls.map((Map<String, String> hall) {
                                return DropdownMenuItem<String>(
                                  value: hall['id'],
                                  child: Text(
                                    hall['name']!,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedHall = newValue;
                                });
                                _validateAllocationDetails();
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a hall';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Role Description
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xff060121).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    const Color(0xff060121).withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Color(0xff060121),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getRoleDescription(selectedRole ?? 'HOD'),
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: isSmallScreen ? 11 : 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Email Input Field
                        _buildInputField(
                          hintText: 'Email*',
                          icon: Icons.email_outlined,
                          controller: _emailController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        _buildPasswordField(
                          controller: _passwordController,
                          hintText: 'Create Password*',
                          isPassword: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Confirm Password Field
                        _buildPasswordField(
                          controller: _confirmController,
                          hintText: 'Confirm Password*',
                          isPassword: false,
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

                        // Sign Up Button - Centered
                        Center(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: _isLoading ||
                                      !_allocationFound ||
                                      !_detailsMatch
                                  ? null
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xff060121),
                                        Color(0xff2d1b5e),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _isLoading ||
                                      !_allocationFound ||
                                      !_detailsMatch
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
                                onTap: _isLoading ||
                                        !_allocationFound ||
                                        !_detailsMatch
                                    ? null
                                    : _handleSignUp,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      vertical: paddingValue * 0.9),
                                  child: Center(
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : Text(
                                            !_allocationFound
                                                ? "VERIFY STAFF ID FIRST"
                                                : !_detailsMatch
                                                    ? "DETAILS DON'T MATCH"
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
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Already have account -> login - Centered
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an admin account? ",
                                style: TextStyle(
                                  fontSize: fontSizeButton,
                                  color: Colors.grey[700],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Get.to(() => const LoginscreenStaff());
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

  // Get role description
  String _getRoleDescription(String role) {
    switch (role) {
      case 'HOD':
        return 'Head of Department: Will see requests from students in selected department only';
      case 'HALL_WARDEN':
        return 'Hall Warden: Will see requests from students in selected hall only';
      case 'STUDENT_AFFAIRS':
        return 'Student Affairs: Will see ALL requests from ALL students';
      case 'SUPER_ADMIN':
        return 'Super Admin: Full system access, can see ALL requests';
      default:
        return 'Select a role to see description';
    }
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
              "Phone Number",
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
                  maxLength: 11, // Changed from 13 to 11 for digits only
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
          ),
        ));
  }

  Widget _buildInputField({
    required String hintText,
    required IconData icon,
    required TextEditingController controller,
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
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(icon, color: const Color(0xff060121)),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            errorStyle: const TextStyle(height: 0.8, fontSize: 12),
          ),
        ));
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool isPassword,
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
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: Color(0xff060121)),
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
        ));
  }
}
