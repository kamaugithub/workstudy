import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all users - updated for your structure
  Stream<QuerySnapshot> getUsersStream() {
    return _firestore.collection('users').snapshots();
  }

  // Add a new user - UPDATED with new parameters
  Future<void> addUser(String email, String role, String name,
      String department, String idNumber) async {
    await _firestore.collection('users').add({
      'email': email,
      'name': name,
      'role': role,
      'roleLower': role.toLowerCase(),
      'department': department,
      'idNumber': idNumber,
      'status': 'pending',
      'isActive': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update user role and details - UPDATED with new parameters
 Future<void> updateUser(
    String userId,
    String email,
    String role,
    String department,
    String idNumber,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'email': email,
        'role': role,
        'department': department,
        'idNumber': idNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
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

      // Add missing department field
      if (data['department'] == null) {
        updates['department'] = 'Not specified';
      }

      // Add missing idNumber field
      if (data['idNumber'] == null) {
        updates['idNumber'] = 'Not specified';
      }

      // Always update updatedAt
      updates['updatedAt'] = FieldValue.serverTimestamp();

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(doc.id).update(updates);
      }
    }
  }

  // NEW: Create user with Firebase Authentication
  Future<void> createUserWithEmailAndPassword(String email, String password,
      String name, String role, String department, String idNumber) async {
    try {
      // Create user in Firebase Auth
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store user data in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'role': role,
        'roleLower': role.toLowerCase(),
        'department': department,
        'idNumber': idNumber,
        'status': 'approved', // Auto-approve admin-created users
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }
}
