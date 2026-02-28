import 'package:exeat_system/screens/editprofile.dart';
import 'package:exeat_system/screens/home_page.dart';
import 'package:exeat_system/screens/login_screen__student.dart';
import 'package:exeat_system/controllers/profile_controller.dart';
import 'package:exeat_system/screens/set_new_password.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final ProfileController _profileController = Get.find<ProfileController>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();

    // Refresh profile data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _profileController.fetchUserData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    double containerWidth =
        screenWidth < 600 ? screenWidth * 0.95 : screenWidth * 0.5;
    double fontSizeTitle = screenWidth < 600 ? 24 : 30;
    double fontSizeText = screenWidth < 600 ? 14 : 16;
    double fontSizeButton = screenWidth < 600 ? 14 : 16;
    double paddingValue = screenWidth < 600 ? 16 : 24;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff060121),
              Color(0xff1a0f3e),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: paddingValue,
                  vertical: paddingValue * 0.8,
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Get.to(() => const HomePage()),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Profile",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: fontSizeTitle,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
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
                    child: FadeTransition(
                      opacity: _animationController,
                      child: Obx(() {
                        // Show loading if data is empty
                        if (_profileController.fullName.value.isEmpty &&
                            FirebaseAuth.instance.currentUser != null) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xff060121),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            // Profile Avatar
                            _buildProfileAvatar(),
                            const SizedBox(height: 24),

                            // Personal Information Card
                            _buildAnimatedCard(
                              delay: 0.1,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(paddingValue * 1.2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xff060121)
                                          .withOpacity(0.08),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.person_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Personal Information",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: fontSizeText + 4,
                                            color: const Color(0xff060121),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    Column(
                                      children: [
                                        _buildInfoRow(
                                          Icons.badge_rounded,
                                          "Full Name",
                                          _profileController.fullName.value,
                                          fontSizeText,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInfoRow(
                                          Icons.email_rounded,
                                          "Email",
                                          _profileController.email.value,
                                          fontSizeText,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInfoRow(
                                          Icons.phone_rounded,
                                          "Phone Number",
                                          _profileController.phone.value,
                                          fontSizeText,
                                        ),
                                        const SizedBox(height: 16),
                                        if (_profileController
                                            .matric.value.isNotEmpty)
                                          _buildInfoRow(
                                            Icons.school_rounded,
                                            "Matric Number",
                                            _profileController.matric.value,
                                            fontSizeText,
                                          ),
                                        if (_profileController
                                            .matric.value.isNotEmpty)
                                          const SizedBox(height: 16),
                                        if (_profileController
                                            .department.value.isNotEmpty)
                                          _buildInfoRow(
                                            Icons.apartment_rounded,
                                            "Department",
                                            _profileController.department.value,
                                            fontSizeText,
                                          ),
                                        if (_profileController
                                            .department.value.isNotEmpty)
                                          const SizedBox(height: 16),
                                        if (_profileController
                                            .hall.value.isNotEmpty)
                                          _buildInfoRow(
                                            Icons.home_rounded,
                                            "Hall of Residence",
                                            _profileController.hall.value,
                                            fontSizeText,
                                          ),
                                        if (_profileController
                                            .hall.value.isNotEmpty)
                                          const SizedBox(height: 16),
                                        _buildInfoRow(
                                          Icons.person_pin_rounded,
                                          "User Role",
                                          _profileController.roleDisplay,
                                          fontSizeText,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Edit Profile Button
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xff060121),
                                            Color(0xff2d1b5e),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xff060121)
                                                .withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () =>
                                              Get.to(() => const EditProfile()),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.edit_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Edit Profile",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: fontSizeButton,
                                                    fontWeight: FontWeight.bold,
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
                            const SizedBox(height: 20),

                            // Account Settings Card
                            _buildAnimatedCard(
                              delay: 0.2,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(paddingValue * 1.2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xff060121)
                                          .withOpacity(0.08),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.settings_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Account Settings",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: fontSizeText + 4,
                                            color: const Color(0xff060121),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Change Password Button
                                    _buildSettingButton(
                                      icon: Icons.lock_reset_rounded,
                                      label: "Change Password",
                                      color: Colors.blue,
                                      onTap: () =>
                                          Get.to(() => const SetNewPassword()),
                                      fontSize: fontSizeButton,
                                    ),
                                    const SizedBox(height: 12),

                                    // Logout Button
                                    _buildSettingButton(
                                      icon: Icons.logout_rounded,
                                      label: "Logout",
                                      color: Colors.red,
                                      onTap: () => _showLogoutDialog(context),
                                      fontSize: fontSizeButton,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      }),
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

  Widget _buildProfileAvatar() {
    return Obx(() => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff060121),
                    Color(0xff2d1b5e),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff060121).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 48,
                  color: Color(0xff060121),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _profileController.fullName.value.isNotEmpty
                  ? _profileController.fullName.value
                  : "User Profile",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xff060121),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _profileController.matric.value.isNotEmpty
                  ? _profileController.matric.value
                  : _profileController.email.value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ));
  }

  Widget _buildAnimatedCard({required double delay, required Widget child}) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, widget) {
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
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, double fontSize) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xff060121).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xff060121),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: fontSize - 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: const Color(0xff060121),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required double fontSize,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color.withOpacity(0.9),
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color.withOpacity(0.5),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xff060121),
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Clear controller data
              _profileController.clearData();

              // Sign out from Firebase
              await FirebaseAuth.instance.signOut();

              Get.back();

              // Clear all routes and go to login
              Get.offAll(() => const LoginScreen());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
