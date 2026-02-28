// models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final String? matricNo; // For students
  final String? staffId; // For admins
  final String? department;
  final String? hall;
  final String role; // 'student' or 'admin'
  final String? profileImage;
  final Timestamp? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phone,
    this.matricNo,
    this.staffId,
    this.department,
    this.hall,
    required this.role,
    this.profileImage = '',
    this.createdAt,
  });

  // Convert from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? data['studentId'] ?? data['adminId'] ?? '',
      email: data['email'] ?? '',
      fullName: data['name'] ?? data['fullName'] ?? '',
      phone: data['phone'] ?? '',
      matricNo: data['matricNumber'] ?? data['matricNo'],
      staffId: data['staffId'],
      department: data['department'],
      hall: data['hall'],
      role: data['role']?.toLowerCase() ?? 'student',
      profileImage: data['profileImage'] ?? '',
      createdAt: data['createdAt'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      if (matricNo != null) 'matricNo': matricNo,
      if (staffId != null) 'staffId': staffId,
      if (department != null) 'department': department,
      if (hall != null) 'hall': hall,
      'role': role,
      'profileImage': profileImage,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  // Check if user is student
  bool get isStudent => role == 'student';

  // Check if user is admin
  bool get isAdmin => role != 'student';
}
