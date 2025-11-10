import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Import for StreamController/Stream

class FirestoreHelper {
  // Use a static instance for convenience
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Methods for Dashboard Functionality ---

  /// 1. Provides a LIVE STREAM of a student's work sessions (for Activity Card and totals)
  static Stream<List<Map<String, dynamic>>> getStudentWorkSessionsStream(
    String studentUid,
  ) {
    return _firestore
        .collection('work_sessions')
        .where('studentId', isEqualTo: studentUid)
        .orderBy('timestamp', descending: true)
        .snapshots() // Use snapshots() for real-time stream
        .map((querySnapshot) {
          return querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'date': data['date'] ?? '',
              'hours': data['hours'] ?? '',
              'status': data['status'] ?? '',
              'description': data['description'] ?? '',
              'timestamp':
                  data['timestamp']
                      as Timestamp?, // Include timestamp for calculation/sorting
            };
          }).toList();
        });
  }

  /// 2. Fetches ALL work sessions for the student (for Excel/PDF Export)
  static Future<List<Map<String, dynamic>>> getAllWorkSessions(
    String studentUid,
  ) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('work_sessions')
              .where('studentId', isEqualTo: studentUid)
              .orderBy('timestamp', descending: true)
              .get(); // Use get() for one-time fetch

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'date': data['date'] ?? '',
          'hours': data['hours'] ?? '',
          'status': data['status'] ?? '',
          'description': data['description'] ?? '',
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
      await _firestore.collection('work_sessions').add(sessionData);
    } catch (e) {
      print('Error adding work session: $e');
      rethrow;
    }
  }

  // The original fetchStudentSessions (kept for compatibility/alternative one-time fetch)
  Future<List<Map<String, dynamic>>> fetchStudentSessions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot =
          await _firestore
              .collection('work_sessions')
              .where('studentId', isEqualTo: user.uid)
              .orderBy('timestamp', descending: true)
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'date': data['date'] ?? '',
          'hours': data['hours'] ?? '',
          'status': data['status'] ?? '',
          'description': data['description'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error fetching student sessions: $e');
      return [];
    }
  }
}
