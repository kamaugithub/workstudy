import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> autoCreateSupervisors() async {
  final firestore = FirebaseFirestore.instance;

  // 🏫 Define your departments here
  final departments = [
    "IT",
    "HR",
    "Corporate Affairs",
    "D.C.F",
    "Library",
    "Sports",
    "Transport",
    "Kitchen",
    "DC3",
  ];

  for (var dept in departments) {
    final query = await firestore
        .collection('users')
        .where('roleLower', isEqualTo: 'supervisor')
        .where('departmentLower', isEqualTo: dept.toLowerCase())
        .get();

    // 👇 Skip if this department already has a supervisor
    if (query.docs.isNotEmpty) {
      print('✅ Supervisor already exists for $dept');
      continue;
    }

    // 👇 Create one automatically
    await firestore.collection('users').add({
      'name': '$dept Supervisor',
      'email': '${dept.replaceAll(' ', '').toLowerCase()}@daystar.ac.ke',
      'department': dept,
      'departmentLower': dept.toLowerCase(),
      'role': 'Supervisor',
      'roleLower': 'supervisor',
      'status': 'active',
      'totalHours': 0,
      'weeklyHours': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('🆕 Supervisor created for $dept');
  }

  print('🎯 Auto supervisor setup complete!');
}
