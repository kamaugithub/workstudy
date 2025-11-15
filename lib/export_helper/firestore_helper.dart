import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Import for StreamController/Stream

class FirestoreHelper {
  // Use a static instance for convenience
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Your project ID from Firebase
  static const String _projectId = 'workstudy-bcda5';

  // Base path for your Firestore collections
  static String get _basePath => 'artifacts/$_projectId/public/data';

  // --- Methods for Dashboard Functionality ---

  /// 1. Provides a LIVE STREAM of a student's work sessions (for Activity Card and totals)
  static Stream<List<Map<String, dynamic>>> getStudentWorkSessionsStream(
    String studentUid,
  ) {
    return _firestore
        .collection(_basePath)
        .doc('work_sessions')
        .collection(
            'work_sessions') // This matches your security rules structure
        .where('studentId', isEqualTo: studentUid)
        .orderBy('submittedAt', descending: true) // Updated field name
        .snapshots() // Use snapshots() for real-time stream
        .map((querySnapshot) {
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date': data['date'] ?? '',
          'hours': data['hours'] ?? 0.0, // Now a number
          'status': data['status'] ?? '',
          'reportDetails': data['reportDetails'] ?? '', // Updated field name
          'submittedAt':
              data['submittedAt'] as Timestamp?, // Updated field name
          'studentId': data['studentId'] ?? '',
          'department': data['department'] ?? '',
        };
      }).toList();
    });
  }

  /// 2. Fetches ALL work sessions for the student (for Excel/PDF Export)
  static Future<List<Map<String, dynamic>>> getAllWorkSessions(
    String studentUid,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_basePath)
          .doc('work_sessions')
          .collection('work_sessions')
          .where('studentId', isEqualTo: studentUid)
          .orderBy('submittedAt', descending: true) // Updated field name
          .get(); // Use get() for one-time fetch

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date': data['date'] ?? '',
          'hours': data['hours'] ?? 0.0, // Now a number
          'status': data['status'] ?? '',
          'reportDetails': data['reportDetails'] ?? '', // Updated field name
          'submittedAt': data['submittedAt'] as Timestamp?,
          'studentId': data['studentId'] ?? '',
          'department': data['department'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error fetching work sessions for export: $e');
      return [];
    }
  }

  /// 3. Adds a new work session (for handleSubmitHours)
  static Future<void> addWorkSession(Map<String, dynamic> sessionData) async {
    try {
      await _firestore
          .collection(_basePath)
          .doc('work_sessions')
          .collection('work_sessions')
          .add(sessionData);
    } catch (e) {
      print('Error adding work session: $e');
      rethrow;
    }
  }

  /// 4. Get user profile data
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(_basePath)
          .doc('users')
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// 5. Update user profile
  static Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection(_basePath)
          .doc('users')
          .collection('users')
          .doc(userId)
          .update(updates);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // The original fetchStudentSessions (kept for compatibility/alternative one-time fetch)
  static Future<List<Map<String, dynamic>>> fetchStudentSessions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection(_basePath)
          .doc('work_sessions')
          .collection('work_sessions')
          .where('studentId', isEqualTo: user.uid)
          .orderBy('submittedAt', descending: true) // Updated field name
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date': data['date'] ?? '',
          'hours': data['hours'] ?? 0.0,
          'status': data['status'] ?? '',
          'reportDetails': data['reportDetails'] ?? '', // Updated field name
          'submittedAt': data['submittedAt'] as Timestamp?,
        };
      }).toList();
    } catch (e) {
      print('Error fetching student sessions: $e');
      return [];
    }
  }

  /// 6. Get supervisor sessions by department (for supervisor dashboard)
  static Stream<List<Map<String, dynamic>>> getSupervisorWorkSessionsStream(
    String department,
  ) {
    return _firestore
        .collection(_basePath)
        .doc('work_sessions')
        .collection('work_sessions')
        .where('department', isEqualTo: department)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date': data['date'] ?? '',
          'hours': data['hours'] ?? 0.0,
          'status': data['status'] ?? '',
          'reportDetails': data['reportDetails'] ?? '',
          'submittedAt': data['submittedAt'] as Timestamp?,
          'studentId': data['studentId'] ?? '',
          'department': data['department'] ?? '',
        };
      }).toList();
    });
  }

  /// 7. Update work session status (for supervisor approval/rejection)
  static Future<void> updateWorkSessionStatus(
      String sessionId, String newStatus) async {
    try {
      await _firestore
          .collection(_basePath)
          .doc('work_sessions')
          .collection('work_sessions')
          .doc(sessionId)
          .update({
        'status': newStatus,
      });
    } catch (e) {
      print('Error updating work session status: $e');
      rethrow;
    }
  }
}
