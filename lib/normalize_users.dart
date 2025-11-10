import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> normalizeUsers() async {
  final firestore = FirebaseFirestore.instance;

  try {
    final usersSnapshot = await firestore.collection('users').get();

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();

      // Normalize roleLower
      if (data.containsKey('role')) {
        final role = data['role'] ?? '';
        await firestore.collection('users').doc(doc.id).update({
          'roleLower': role.toString().toLowerCase(),
        });
      }

      // Normalize departmentLower
      if (data.containsKey('department')) {
        final department = data['department'] ?? '';
        await firestore.collection('users').doc(doc.id).update({
          'departmentLower': department.toString().toLowerCase(),
        });
      }

      print('Normalized user: ${doc.id}');
    }

    print('✅ All users normalized successfully.');
  } catch (e) {
    print('Error normalizing users: $e');
  }
}
