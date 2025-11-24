import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class FirestoreHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- SIMPLIFIED Methods for Dashboard Functionality ---

  /// 1. Provides a LIVE STREAM of a student's work sessions
  static Stream<List<Map<String, dynamic>>> getStudentWorkSessionsStream(
    String studentUid,
  ) {
    try {
      return _firestore
          .collection('work_sessions') // Direct collection access
          .where('studentId', isEqualTo: studentUid)
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
    } catch (e) {
      print('❌ Error in getStudentWorkSessionsStream: $e');
      // Return an empty stream on error
      return Stream.value([]);
    }
  }

  /// 2. Fetches ALL work sessions for the student (for Excel/PDF Export)
  static Future<List<Map<String, dynamic>>> getAllWorkSessions(
    String studentUid,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('work_sessions') // Direct collection access
          .where('studentId', isEqualTo: studentUid)
          .orderBy('submittedAt', descending: true)
          .get();

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
    } catch (e) {
      print('❌ Error fetching work sessions for export: $e');
      return [];
    }
  }

  /// 3. Adds a new work session
  static Future<void> addWorkSession(Map<String, dynamic> sessionData) async {
    try {
      await _firestore
          .collection('work_sessions') // Direct collection access
          .add(sessionData);
      print('✅ Work session added successfully');
    } catch (e) {
      print('❌ Error adding work session: $e');
      rethrow;
    }
  }

  /// 4. Get user profile   data
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('users') // Direct collection access
          .doc(userId)
          .get();

      if (doc.exists) {
        print('✅ User profile found for: $userId');
        return doc.data();
      } else {
        print('❌ User profile not found for: $userId');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching user profile: $e');
      return null;
    }
  }

  /// 5. Update user profile
  static Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection('users') // Direct collection access
          .doc(userId)
          .update(updates);
      print('✅ User profile updated for: $userId');
    } catch (e) {
      print('❌ Error updating user profile: $e');
      rethrow;
    }
  }

  /// 6. Get supervisor sessions by department
  static Stream<List<Map<String, dynamic>>> getSupervisorWorkSessionsStream(
    String department,
  ) {
    try {
      return _firestore
          .collection('work_sessions') // Direct collection access
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
    } catch (e) {
      print('❌ Error in getSupervisorWorkSessionsStream: $e');
      return Stream.value([]);
    }
  }

  /// 7. Update work session status (for supervisor approval/rejection)
  static Future<void> updateWorkSessionStatus(
      String sessionId, String newStatus) async {
    try {
      await _firestore
          .collection('work_sessions') // Direct collection access
          .doc(sessionId)
          .update({
        'status': newStatus,
      });
      print('✅ Work session status updated: $sessionId -> $newStatus');
    } catch (e) {
      print('❌ Error updating work session status: $e');
      rethrow;
    }
  }

  /// 8. DEBUG: Check if collections exist
  static Future<void> debugCollections() async {
    try {
      print('🔍 DEBUG: Checking Firestore collections...');

      // Check users collection
      final usersQuery = await _firestore.collection('users').limit(1).get();
      print('✅ Users collection exists: ${usersQuery.docs.length} documents');

      // Check work_sessions collection
      final sessionsQuery =
          await _firestore.collection('work_sessions').limit(1).get();
      print(
          '✅ Work sessions collection exists: ${sessionsQuery.docs.length} documents');
    } catch (e) {
      print('❌ DEBUG collection error: $e');
    }
  }
}
