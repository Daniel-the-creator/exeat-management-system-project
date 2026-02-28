// models/exeat_request.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ExeatRequest {
  final String? id;
  final String studentId;
  final String studentName;
  final String studentMatric;
  final String destination;
  final String leaveDate;
  final String returnDate;
  final String reason;
  final String status;
  final String priorityLevel;
  final String studentEmail;
  final String studentPhone;
  final String contactPerson;
  final String contactNumber;
  final String guardianApproval;
  final String leaveTime;
  final String returnTime;
  final String? adminNote;
  final String? processedBy;
  final Timestamp createdAt;
  final Timestamp? processedAt;
  final Timestamp? updatedAt;

  ExeatRequest({
    this.id,
    required this.studentId,
    required this.studentName,
    required this.studentMatric,
    required this.destination,
    required this.leaveDate,
    required this.returnDate,
    required this.reason,
    this.status = 'pending',
    this.priorityLevel = 'NORMAL',
    required this.studentEmail,
    required this.studentPhone,
    required this.contactPerson,
    required this.contactNumber,
    required this.guardianApproval,
    required this.leaveTime,
    required this.returnTime,
    this.adminNote,
    this.processedBy,
    required this.createdAt,
    this.processedAt,
    this.updatedAt,
  });

  factory ExeatRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ExeatRequest(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentMatric: data['studentMatric'] ?? '',
      destination: data['destination'] ?? '',
      leaveDate: data['leaveDate'] ?? '',
      returnDate: data['returnDate'] ?? '',
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      priorityLevel: data['priorityLevel'] ?? 'NORMAL',
      studentEmail: data['studentEmail'] ?? '',
      studentPhone: data['studentPhone'] ?? '',
      contactPerson: data['contactPerson'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      guardianApproval: data['guardianApproval'] ?? '',
      leaveTime: data['leaveTime'] ?? '',
      returnTime: data['returnTime'] ?? '',
      adminNote: data['adminNote'],
      processedBy: data['processedBy'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      processedAt: data['processedAt'],
      updatedAt: data['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentMatric': studentMatric,
      'destination': destination,
      'leaveDate': leaveDate,
      'returnDate': returnDate,
      'reason': reason,
      'status': status,
      'priorityLevel': priorityLevel,
      'studentEmail': studentEmail,
      'studentPhone': studentPhone,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
      'guardianApproval': guardianApproval,
      'leaveTime': leaveTime,
      'returnTime': returnTime,
      if (adminNote != null) 'adminNote': adminNote,
      if (processedBy != null) 'processedBy': processedBy,
      'createdAt': createdAt,
      if (processedAt != null) 'processedAt': processedAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  // Convert from RequestModel to ExeatRequest (for compatibility)
  factory ExeatRequest.fromRequestModel(Map<String, dynamic> data) {
    return ExeatRequest(
      id: data['id'] ?? data['requestId'],
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentMatric: data['studentMatric'] ?? '',
      destination: data['destination'] ?? '',
      leaveDate: data['leaveDate'] ?? '',
      returnDate: data['returnDate'] ?? '',
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      priorityLevel: data['priorityLevel'] ?? 'NORMAL',
      studentEmail: data['studentEmail'] ?? '',
      studentPhone: data['studentPhone'] ?? '',
      contactPerson: data['contactPerson'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      guardianApproval: data['guardianApproval'] ?? '',
      leaveTime: data['leaveTime'] ?? '',
      returnTime: data['returnTime'] ?? '',
      adminNote: data['adminNote'],
      processedBy: data['processedBy'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      processedAt: data['processedAt'],
      updatedAt: data['updatedAt'],
    );
  }
}
