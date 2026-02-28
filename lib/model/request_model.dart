// model/request_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RequestModel {
  final String requestId;
  final String studentId;
  final String studentName;
  final String studentMatric;
  final String studentEmail;
  final String studentPhone;
  final String destination;
  final String leaveDate;
  final String returnDate;
  final String reason;
  final String status;
  final String priorityLevel;
  final String leaveTime;
  final String returnTime;
  final String contactPerson;
  final String contactNumber;
  final String guardianApproval;
  final String? adminNote;
  final String? processedBy;
  final Timestamp createdAt;
  final Timestamp? processedAt;
  final Timestamp updatedAt;
  final String? hallId;
  final String? departmentId;

  // New fields for approval tracking
  final String? hodApprovedBy;
  final String? studentAffairsApprovedBy;
  final String? wardenApprovedBy;
  final String? rejectedBy;
  final Timestamp? hodApprovedAt;
  final Timestamp? studentAffairsApprovedAt;
  final Timestamp? wardenApprovedAt;
  final Timestamp? rejectedAt;
  final Timestamp? fullyApprovedAt;

  RequestModel({
    required this.requestId,
    required this.studentId,
    required this.studentName,
    required this.studentMatric,
    required this.studentEmail,
    required this.studentPhone,
    required this.destination,
    required this.leaveDate,
    required this.returnDate,
    required this.reason,
    required this.status,
    required this.priorityLevel,
    required this.leaveTime,
    required this.returnTime,
    required this.contactPerson,
    required this.contactNumber,
    required this.guardianApproval,
    this.adminNote,
    this.processedBy,
    required this.createdAt,
    this.processedAt,
    required this.updatedAt,
    this.hallId,
    this.departmentId,

    // New fields
    this.hodApprovedBy,
    this.studentAffairsApprovedBy,
    this.wardenApprovedBy,
    this.rejectedBy,
    this.hodApprovedAt,
    this.studentAffairsApprovedAt,
    this.wardenApprovedAt,
    this.rejectedAt,
    this.fullyApprovedAt,
  });

  // Convert from Firestore document data
  factory RequestModel.fromMap(Map<String, dynamic> map, String id) {
    return RequestModel(
      requestId: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentMatric: map['studentMatric'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      studentPhone: map['studentPhone'] ?? '',
      destination: map['destination'] ?? '',
      leaveDate: map['leaveDate'] ?? '',
      returnDate: map['returnDate'] ?? '',
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      priorityLevel: map['priorityLevel'] ?? 'NORMAL',
      leaveTime: map['leaveTime'] ?? '',
      returnTime: map['returnTime'] ?? '',
      contactPerson: map['contactPerson'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
      guardianApproval: map['guardianApproval'] ?? '',
      adminNote: map['adminNote'],
      processedBy: map['processedBy'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      processedAt: map['processedAt'],
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
      hallId: map['hallId'],
      departmentId: map['departmentId'],

      // New fields
      hodApprovedBy: map['hodApprovedBy'],
      studentAffairsApprovedBy: map['studentAffairsApprovedBy'],
      wardenApprovedBy: map['wardenApprovedBy'],
      rejectedBy: map['rejectedBy'],
      hodApprovedAt: map['hodApprovedAt'],
      studentAffairsApprovedAt: map['studentAffairsApprovedAt'],
      wardenApprovedAt: map['wardenApprovedAt'],
      rejectedAt: map['rejectedAt'],
      fullyApprovedAt: map['fullyApprovedAt'],
    );
  }

  // Alternative: Convert from QueryDocumentSnapshot
  factory RequestModel.fromDocument(QueryDocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return RequestModel.fromMap(map, doc.id);
  }

  // Alternative: Convert from DocumentSnapshot
  factory RequestModel.fromSnapshot(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return RequestModel.fromMap(map, doc.id);
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'studentId': studentId,
      'studentName': studentName,
      'studentMatric': studentMatric,
      'studentEmail': studentEmail,
      'studentPhone': studentPhone,
      'destination': destination,
      'leaveDate': leaveDate,
      'returnDate': returnDate,
      'reason': reason,
      'status': status,
      'priorityLevel': priorityLevel,
      'leaveTime': leaveTime,
      'returnTime': returnTime,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
      'guardianApproval': guardianApproval,
      'adminNote': adminNote,
      'processedBy': processedBy,
      'createdAt': createdAt,
      'processedAt': processedAt,
      'updatedAt': updatedAt,
      'hallId': hallId,
      'departmentId': departmentId,

      // New fields
      'hodApprovedBy': hodApprovedBy,
      'studentAffairsApprovedBy': studentAffairsApprovedBy,
      'wardenApprovedBy': wardenApprovedBy,
      'rejectedBy': rejectedBy,
      'hodApprovedAt': hodApprovedAt,
      'studentAffairsApprovedAt': studentAffairsApprovedAt,
      'wardenApprovedAt': wardenApprovedAt,
      'rejectedAt': rejectedAt,
      'fullyApprovedAt': fullyApprovedAt,
    };
  }

  // Create a copy with updated fields
  RequestModel copyWith({
    String? requestId,
    String? studentId,
    String? studentName,
    String? studentMatric,
    String? studentEmail,
    String? studentPhone,
    String? destination,
    String? leaveDate,
    String? returnDate,
    String? reason,
    String? status,
    String? priorityLevel,
    String? leaveTime,
    String? returnTime,
    String? contactPerson,
    String? contactNumber,
    String? guardianApproval,
    String? adminNote,
    String? processedBy,
    Timestamp? createdAt,
    Timestamp? processedAt,
    Timestamp? updatedAt,
    String? hallId,
    String? departmentId,

    // New fields
    String? hodApprovedBy,
    String? studentAffairsApprovedBy,
    String? wardenApprovedBy,
    String? rejectedBy,
    Timestamp? hodApprovedAt,
    Timestamp? studentAffairsApprovedAt,
    Timestamp? wardenApprovedAt,
    Timestamp? rejectedAt,
    Timestamp? fullyApprovedAt,
  }) {
    return RequestModel(
      requestId: requestId ?? this.requestId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentMatric: studentMatric ?? this.studentMatric,
      studentEmail: studentEmail ?? this.studentEmail,
      studentPhone: studentPhone ?? this.studentPhone,
      destination: destination ?? this.destination,
      leaveDate: leaveDate ?? this.leaveDate,
      returnDate: returnDate ?? this.returnDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      priorityLevel: priorityLevel ?? this.priorityLevel,
      leaveTime: leaveTime ?? this.leaveTime,
      returnTime: returnTime ?? this.returnTime,
      contactPerson: contactPerson ?? this.contactPerson,
      contactNumber: contactNumber ?? this.contactNumber,
      guardianApproval: guardianApproval ?? this.guardianApproval,
      adminNote: adminNote ?? this.adminNote,
      processedBy: processedBy ?? this.processedBy,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hallId: hallId ?? this.hallId,
      departmentId: departmentId ?? this.departmentId,

      // New fields
      hodApprovedBy: hodApprovedBy ?? this.hodApprovedBy,
      studentAffairsApprovedBy:
          studentAffairsApprovedBy ?? this.studentAffairsApprovedBy,
      wardenApprovedBy: wardenApprovedBy ?? this.wardenApprovedBy,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      hodApprovedAt: hodApprovedAt ?? this.hodApprovedAt,
      studentAffairsApprovedAt:
          studentAffairsApprovedAt ?? this.studentAffairsApprovedAt,
      wardenApprovedAt: wardenApprovedAt ?? this.wardenApprovedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      fullyApprovedAt: fullyApprovedAt ?? this.fullyApprovedAt,
    );
  }

  // Helper methods
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';

  // Enhanced status checkers for multi-level approval
  bool get isPendingHod => status == 'pending_hod';
  bool get isPendingStudentAffairs => status == 'pending_student_affairs';
  bool get isPendingWarden => status == 'pending_warden';

  // Approval tracking helpers
  bool get isApprovedByHod =>
      hodApprovedBy != null && hodApprovedBy!.isNotEmpty;
  bool get isApprovedByStudentAffairs =>
      studentAffairsApprovedBy != null && studentAffairsApprovedBy!.isNotEmpty;
  bool get isApprovedByWarden =>
      wardenApprovedBy != null && wardenApprovedBy!.isNotEmpty;
  bool get hasBeenRejected => rejectedBy != null && rejectedBy!.isNotEmpty;

  DateTime get createdDateTime => createdAt.toDate();
  DateTime? get processedDateTime => processedAt?.toDate();

  // New DateTime getters
  DateTime? get hodApprovedDateTime => hodApprovedAt?.toDate();
  DateTime? get studentAffairsApprovedDateTime =>
      studentAffairsApprovedAt?.toDate();
  DateTime? get wardenApprovedDateTime => wardenApprovedAt?.toDate();
  DateTime? get rejectedDateTime => rejectedAt?.toDate();
  DateTime? get fullyApprovedDateTime => fullyApprovedAt?.toDate();

  // Status color getter
  String get statusColor {
    switch (status) {
      case 'pending':
      case 'pending_hod':
      case 'pending_student_affairs':
      case 'pending_warden':
        return 'orange';
      case 'approved':
        return 'green';
      case 'rejected':
        return 'red';
      case 'cancelled':
        return 'grey';
      default:
        return 'blue';
    }
  }

  // Priority color getter
  String get priorityColor {
    switch (priorityLevel) {
      case 'EMERGENCY':
        return 'red';
      case 'MEDICAL':
        return 'orange';
      case 'FAMILY':
        return 'blue';
      case 'NORMAL':
        return 'green';
      default:
        return 'grey';
    }
  }

  @override
  String toString() {
    return 'RequestModel(requestId: $requestId, studentName: $studentName, status: $status, destination: $destination)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RequestModel && other.requestId == requestId;
  }

  @override
  int get hashCode => requestId.hashCode;
}
