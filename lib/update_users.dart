import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> normalizeUsers() async {
  final firestore = FirebaseFirestore.instance;
  final users = await firestore.collection('users').get();

  for (var doc in users.docs) {
    final data = doc.data();

    final role = (data['role'] ?? '').toString();
    final department = (data['department'] ?? '').toString();

    // Skip if already normalized
    if (data.containsKey('roleLower') && data.containsKey('departmentLower')) {
      print('✅ Already normalized: ${doc.id}');
      continue;
    }

    

    await doc.reference.update({
      'roleLower': role.toLowerCase(),
      'departmentLower': department.toLowerCase(),
    });

    print('🔧 Updated: ${doc.id} ($role - $department)');
  }

  print('🎯 Normalization complete!');
}
