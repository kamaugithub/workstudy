import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> addRoleLowerToAllUsers() async {
  final firestore = FirebaseFirestore.instance;

  try {
    final usersSnapshot = await firestore.collection('users').get();

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      if (data.containsKey('role')) {
        final role = data['role'] ?? '';
        await firestore.collection('users').doc(doc.id).update({
          'roleLower': role.toString().toLowerCase(),
        });
        print('Updated ${doc.id} with roleLower: ${role.toLowerCase()}');
      }
    }

    print('✅ All users updated successfully.');
  } catch (e) {
    print('Error updating users: $e');
  }
}
