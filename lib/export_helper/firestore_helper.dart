import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch all work sessions for the current student
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
