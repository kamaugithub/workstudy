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
  final String? idNumber; // Add this field

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
    this.idNumber, // Add this
  });

  // Convert Firestore document to AppUser object
  factory AppUser.fromFirestore(Map<String, dynamic> data, String documentId) {
    return AppUser(
      id: documentId,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      department: data['department'] ?? '',
      status: data['status'] ?? 'pending',
      totalHours: (data['totalHours'] ?? 0).toDouble(),
      weeklyHours: (data['weeklyHours'] ?? 0).toDouble(),
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      supervisorId: data['supervisorId'],
      rejectionReason: data['rejectionReason'],
      idNumber: data['idNumber'], // Add this
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
      if (idNumber != null) 'idNumber': idNumber, // Add this
    };
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return DateTime.now();
  }

  // Helper methods for approval system
  bool get isStudent => role.toLowerCase() == 'student';
  bool get isSupervisor => role.toLowerCase() == 'supervisor';
  bool get isAdmin => role.toLowerCase() == 'admin';

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isDeclined => status == 'declined';
}
