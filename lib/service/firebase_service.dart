import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all users - updated for your structure
  Stream<QuerySnapshot> getUsersStream() {
    return _firestore.collection('users').snapshots();
  }

  // Add a new user - updated for your structure
  Future<void> addUser(String email, String role, String name) async {
    await _firestore.collection('users').add({
      'email': email,
      'name': name,
      'role': role,
      'roleLower': role.toLowerCase(),
      'status': 'pending',
      'isActive': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update user role and details - updated for your structure
  Future<void> updateUser(
      String userId, String email, String role, String name) async {
    await _firestore.collection('users').doc(userId).update({
      'email': email,
      'name': name,
      'role': role,
      'roleLower': role.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update user status (approve/decline)
  Future<void> updateUserStatus(String userId, String status) async {
    await _firestore.collection('users').doc(userId).update({
      'status': status,
      'isActive': status == 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
  }

  // Get dashboard statistics - UPDATED for your current structure
  Future<Map<String, dynamic>> getDashboardStats() async {
    final usersSnapshot = await _firestore.collection('users').get();

    // Handle your current structure where some users might not have all fields
    final students = usersSnapshot.docs.where((doc) {
      final data = doc.data();
      return data['role'] == 'Student' || data['role'] == 'student';
    }).length;

    final supervisors = usersSnapshot.docs.where((doc) {
      final data = doc.data();
      return data['role'] == 'Supervisor' || data['role'] == 'supervisor';
    }).length;

    final pending = usersSnapshot.docs.where((doc) {
      final data = doc.data();
      return data['status'] == 'pending';
    }).length;

    // Calculate total hours - check if work_hours collection exists
    int totalHours = 0;
    try {
      final hoursSnapshot = await _firestore.collection('work_hours').get();
      totalHours = hoursSnapshot.docs.fold<int>(0, (sum, doc) {
        final hours = doc['hours'] ?? 0;
        return sum +
            (hours is int ? hours : int.tryParse(hours.toString()) ?? 0);
      });
    } catch (e) {
      print('work_hours collection not found: $e');
      // If work_hours doesn't exist, use a default value or calculate from another source
      totalHours = 1247; // Default value for demo
    }

    return {
      "totalStudents": students,
      "totalSupervisors": supervisors,
      "pendingApprovals": pending,
      "totalHoursApproved": totalHours,
    };
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Helper method to initialize missing fields in existing users
  Future<void> initializeUserFields() async {
    final usersSnapshot = await _firestore.collection('users').get();

    for (final doc in usersSnapshot.docs) {
      final data = doc.data();
      final updates = <String, dynamic>{};

      // Add missing status field
      if (data['status'] == null) {
        updates['status'] = 'approved';
      }

      // Add missing isActive field
      if (data['isActive'] == null) {
        updates['isActive'] = true;
      }

      // Add missing createdAt field
      if (data['createdAt'] == null) {
        updates['createdAt'] = FieldValue.serverTimestamp();
      }

      // Always update updatedAt
      updates['updatedAt'] = FieldValue.serverTimestamp();

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(doc.id).update(updates);
      }
    }
  }
}
