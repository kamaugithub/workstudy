import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final String department;
  final String status;
  final double totalHours;
  final double weeklyHours;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? supervisorId;
  final String? rejectionReason;
  final String? idNumber;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.department,
    required this.status,
    required this.totalHours,
    required this.weeklyHours,
    required this.createdAt,
    required this.updatedAt,
    this.supervisorId,
    this.rejectionReason,
    this.idNumber,
  });

  // Convert Firestore document to AppUser object
  factory AppUser.fromFirestore(Map<String, dynamic> data, String documentId) {
    return AppUser(
      id: documentId,
      email: data['email']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      role: data['role']?.toString() ?? '',
      department: data['department']?.toString() ?? '',
      status: data['status']?.toString() ?? 'pending',
      totalHours: _parseDouble(data['totalHours']),
      weeklyHours: _parseDouble(data['weeklyHours']),
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      supervisorId: data['supervisorId']?.toString(),
      rejectionReason: data['rejectionReason']?.toString(),
      idNumber: data['idNumber']?.toString(),
    );
  }

  // Convert AppUser object to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'department': department,
      'status': status,
      'totalHours': totalHours,
      'weeklyHours': weeklyHours,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      if (supervisorId != null) 'supervisorId': supervisorId,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (idNumber != null) 'idNumber': idNumber,
    };
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now();
    }

    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }

    if (timestamp is DateTime) {
      return timestamp;
    }

    // Try to parse as string if needed
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }

    return DateTime.now();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Helper methods for approval system
  bool get isStudent => role.toLowerCase() == 'student';
  bool get isSupervisor => role.toLowerCase() == 'supervisor';
  bool get isAdmin => role.toLowerCase() == 'admin';

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isDeclined => status == 'declined';
}
