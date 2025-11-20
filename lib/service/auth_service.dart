import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // =========================
  // SIGN UP (PENDING APPROVAL)
  // =========================
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String role,
    required String department,
    required String idNumber,
  }) async {
    try {
      print('🚀 Signup started for $email');
      print('📋 Role: $role, Department: $department, ID: $idNumber');

      // Normalize email for consistency
      final normalizedEmail = email.toLowerCase().trim();

      // Check email exists
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'email-already-exists',
          message: 'Email already exists.',
        );
      }

      // Check ID exists
      final idQuery = await _firestore
          .collection('users')
          .where('idNumber', isEqualTo: idNumber)
          .get();

      if (idQuery.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'id-already-exists',
          message: 'ID number already registered.',
        );
      }

      // Validate department exists
      await _validateDepartment(department);

      // Create Firebase user
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final uid = credential.user!.uid;
      print('✅ Firebase account created: $uid');

      // Auto assign supervisor for student
      String? supervisorId;
      if (role.toLowerCase() == 'student') {
        supervisorId = await _assignSupervisorForStudent(department, uid);
      }

      final name = _generateNameFromEmail(normalizedEmail);

      final newUser = AppUser(
        id: uid,
        email: normalizedEmail,
        name: name,
        role: role.toLowerCase(), // Convert to lowercase for consistency
        department: department,
        status: 'pending',
        totalHours: 0,
        weeklyHours: 0,
        supervisorId: supervisorId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final userData = {
        ...newUser.toFirestore(),
        'idNumber': idNumber,
      };

      await _firestore.collection('users').doc(uid).set(userData);

      // Update department statistics
      await _updateDepartmentStats(department, role, 'add');

      print('🎉 Signup completed for $normalizedEmail');
      print('📝 User document created with ID: $uid');
      return newUser;
    } catch (e) {
      print('❌ Signup error: $e');

      // Clean up: if Firebase user was created but Firestore failed, delete the auth user
      if (_auth.currentUser != null) {
        try {
          await _auth.currentUser!.delete();
        } catch (deleteError) {
          print('⚠ Could not delete auth user: $deleteError');
        }
      }

      rethrow;
    }
  }

  // ================
  // NAME GENERATOR
  // ================
  String _generateNameFromEmail(String email) {
    try {
      String base = email.split('@')[0];
      base = base.replaceAll('.', ' ').replaceAll('_', ' ');
      return base
          .split(' ')
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
          .join(' ');
    } catch (_) {
      return 'User';
    }
  }

  // ====================
  // SIGN IN WITH CHECKS - FIXED VERSION
  // ====================
  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Signing in $email');

      // Normalize email for consistency
      final normalizedEmail = email.toLowerCase().trim();

      // Sign in with Firebase Auth first
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final uid = credential.user!.uid;
      print('✅ Firebase authentication successful for UID: $uid');

      // ALWAYS search by email instead of UID to ensure we find the user
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('❌ No user document found for email: $normalizedEmail');
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user account found for this email.',
        );
      }

      final userDoc = query.docs.first;
      final data = userDoc.data();

      print('📄 User document found with ID: ${userDoc.id}');
      print(
          '📊 User status: ${data['status']}, role: ${data['role']}, department: ${data['department']}');

      final user = AppUser.fromFirestore(data, userDoc.id);

      // Approval check
      if (!user.isApproved) {
        await _auth.signOut();

        if (user.isDeclined) {
          throw FirebaseAuthException(
            code: 'account-declined',
            message: user.rejectionReason ?? 'Your account has been declined.',
          );
        }

        throw FirebaseAuthException(
          code: 'pending-approval',
          message:
              'Your account is pending approval. Please wait for admin approval.',
        );
      }

      print(
          '✅ Login successful for ${user.email} (${user.role}) in ${user.department}');
      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Unexpected signin error: $e');
      rethrow;
    }
  }

  // SUPERVISOR ASSIGNMENT LOGIC - FIXED VERSION
  Future<String?> _assignSupervisorForStudent(
      String department, String studentId) async {
    try {
      if (department.isEmpty) {
        print('⚠ No department specified for student $studentId');
        return null;
      }

      print('🔍 Finding supervisor for department: $department');

      // DEBUG: First let's see ALL users in this department
      final allDeptUsers = await _firestore
          .collection('users')
          .where('department', isEqualTo: department)
          .get();

      print('📊 DEBUG - All users in $department:');
      for (final doc in allDeptUsers.docs) {
        final data = doc.data();
        print(
            '   - ${data['name']} (${data['email']}): ${data['role']} - ${data['status']} - ID: ${doc.id}');
      }

      // FIX: Get all approved users in department and filter for supervisors manually
      final approvedUsersQuery = await _firestore
          .collection('users')
          .where('department', isEqualTo: department)
          .where('status', isEqualTo: 'approved')
          .get();

      // Manual filtering to handle case sensitivity in role field
      final approvedSupervisors = approvedUsersQuery.docs.where((doc) {
        final role = doc.data()['role']?.toString().toLowerCase();
        return role == 'supervisor';
      }).toList();

      print(
          '✅ Found ${approvedSupervisors.length} approved supervisor(s) in $department');

      if (approvedSupervisors.isEmpty) {
        print('❌ No approved supervisors found. Checking data issues...');

        // Check if there are any supervisors with different status
        final allDeptUsers = await _firestore
            .collection('users')
            .where('department', isEqualTo: department)
            .get();

        // Manual filtering for supervisors with any status
        final allSupervisors = allDeptUsers.docs.where((doc) {
          final role = doc.data()['role']?.toString().toLowerCase();
          return role == 'supervisor';
        }).toList();

        print('🔍 Supervisors with any status: ${allSupervisors.length}');
        for (final doc in allSupervisors) {
          final data = doc.data();
          print(
              '   - ${data['name']}: status = ${data['status']}, role = ${data['role']}');
        }
        return null;
      }

      // Strategy: Assign to supervisor with least students for load balancing
      String? selectedSupervisorId;
      int minStudentCount = 999999;

      for (final supervisorDoc in approvedSupervisors) {
        final supervisorId = supervisorDoc.id;
        final supervisorData = supervisorDoc.data();

        // Count current students for this supervisor
        final studentsCount = await _countStudentsForSupervisor(supervisorId);

        print(
            '   - Supervisor ${supervisorData['name']} (${supervisorData['email']}) has $studentsCount students');

        if (studentsCount < minStudentCount) {
          minStudentCount = studentsCount;
          selectedSupervisorId = supervisorId;
        }
      }

      if (selectedSupervisorId != null) {
        print(
            '🎯 Assigned student to supervisor: $selectedSupervisorId with $minStudentCount existing students');

        // Update supervisor's student count
        await _updateSupervisorStudentCount(selectedSupervisorId, 1);
      }

      return selectedSupervisorId;
    } catch (e) {
      print('❌ Supervisor assignment error: $e');
      return null;
    }
  }

  // ===============================
  // DEPARTMENT MANAGEMENT
  // ===============================
  Future<void> _validateDepartment(String department) async {
    try {
      // You can add department validation logic here
      // For example, check against a list of valid departments
      print('✅ Department validated: $department');
    } catch (e) {
      print('❌ Department validation error: $e');
      rethrow;
    }
  }

  Future<void> _updateDepartmentStats(
      String department, String role, String operation) async {
    try {
      final docRef = _firestore.collection('department_stats').doc(department);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          // Create new department stats
          transaction.set(docRef, {
            'department': department,
            'totalStudents': role.toLowerCase() == 'student'
                ? (operation == 'add' ? 1 : -1)
                : 0,
            'totalSupervisors': role.toLowerCase() == 'supervisor'
                ? (operation == 'add' ? 1 : -1)
                : 0,
            'pendingApprovals': operation == 'add' ? 1 : 0,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
        } else {
          // Update existing stats
          final data = doc.data()!;
          final updateData = <String, dynamic>{
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          };

          if (role.toLowerCase() == 'student') {
            updateData['totalStudents'] =
                (data['totalStudents'] ?? 0) + (operation == 'add' ? 1 : -1);
          } else if (role.toLowerCase() == 'supervisor') {
            updateData['totalSupervisors'] =
                (data['totalSupervisors'] ?? 0) + (operation == 'add' ? 1 : -1);
          }

          if (operation == 'add') {
            updateData['pendingApprovals'] =
                (data['pendingApprovals'] ?? 0) + 1;
          }

          transaction.update(docRef, updateData);
        }
      });
    } catch (e) {
      print('❌ Department stats update error: $e');
    }
  }

  // ===============================
  // STUDENT-SUPERVISOR MANAGEMENT
  // ===============================
  Future<int> _countStudentsForSupervisor(String supervisorId) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('supervisorId', isEqualTo: supervisorId)
          .where('role', isEqualTo: 'student')
          .where('status', isEqualTo: 'approved')
          .get();

      return query.docs.length;
    } catch (e) {
      print('❌ Count students error: $e');
      return 0;
    }
  }

  Future<void> _updateSupervisorStudentCount(
      String supervisorId, int change) async {
    try {
      await _firestore.collection('users').doc(supervisorId).update({
        'studentCount': FieldValue.increment(change),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('❌ Update supervisor student count error: $e');
    }
  }

  // ===============================
  // FIXED APPROVAL CHECK
  // ===============================
  Future<void> checkUserApproval(String userId) async {
    try {
      print('🔍 Checking approval for $userId');

      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        print('❌ No user doc found during approval check');
        // Try to find by email as fallback
        final currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.email != null) {
          print('🔄 Falling back to email search: ${currentUser.email}');
          final query = await _firestore
              .collection('users')
              .where('email',
                  isEqualTo: currentUser.email!.toLowerCase().trim())
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            final userDoc = query.docs.first;
            final data = userDoc.data();
            final user = AppUser.fromFirestore(data, userDoc.id);

            if (!user.isApproved) {
              await _auth.signOut();
              if (user.isDeclined) {
                throw FirebaseAuthException(
                  code: 'account-declined',
                  message: user.rejectionReason ??
                      'Your account was declined by admin.',
                );
              }
              throw FirebaseAuthException(
                code: 'pending-approval',
                message: 'Your account is pending admin approval.',
              );
            }
            return;
          }
        }
        return;
      }

      final data = doc.data();
      if (data == null) return;

      final user = AppUser.fromFirestore(data, doc.id);

      if (!user.isApproved) {
        await _auth.signOut();

        if (user.isDeclined) {
          throw FirebaseAuthException(
            code: 'account-declined',
            message:
                user.rejectionReason ?? 'Your account was declined by admin.',
          );
        }

        throw FirebaseAuthException(
          code: 'pending-approval',
          message: 'Your account is pending admin approval.',
        );
      }
    } catch (e) {
      print('❌ Approval check error: $e');
      rethrow;
    }
  }

  // =============
  // ADMIN ACTIONS
  // =============
  Future<void> approveUser(String userId) async {
    try {
      // Get user data first to update department stats
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) throw Exception('User not found');

      final userData = userDoc.data()!;
      final department = userData['department'];
      final role = userData['role'];

      // Update user status
      await _firestore.collection('users').doc(userId).update({
        'status': 'approved',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'rejectionReason': FieldValue.delete(),
      });

      // Update department stats
      await _updateDepartmentStats(department, role, 'approve');

      print('✅ User $userId approved successfully in department: $department');
    } catch (e) {
      print('❌ Error approving user: $e');
      rethrow;
    }
  }

  Future<void> declineUser(String userId, String reason) async {
    try {
      // Get user data first to update department stats
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) throw Exception('User not found');

      final userData = userDoc.data()!;
      final department = userData['department'];
      final role = userData['role'];

      await _firestore.collection('users').doc(userId).update({
        'status': 'declined',
        'rejectionReason': reason,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Update department stats
      await _updateDepartmentStats(department, role, 'decline');

      print('✅ User $userId declined with reason: $reason');
    } catch (e) {
      print('❌ Error declining user: $e');
      rethrow;
    }
  }

  // =============
  // GET USERS WITH DEPARTMENT FILTERS
  // =============
  Stream<List<AppUser>> getPendingUsers() {
    return _firestore
        .collection('users')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppUser.fromFirestore(d.data(), d.id))
            .toList());
  }

  Stream<List<AppUser>> getAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppUser.fromFirestore(d.data(), d.id))
            .toList());
  }

  // Get users by department
  Stream<List<AppUser>> getUsersByDepartment(String department) {
    return _firestore
        .collection('users')
        .where('department', isEqualTo: department)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppUser.fromFirestore(d.data(), d.id))
            .toList());
  }

  // Get students for a specific supervisor
  Stream<List<AppUser>> getStudentsForSupervisor(String supervisorId) {
    return _firestore
        .collection('users')
        .where('supervisorId', isEqualTo: supervisorId)
        .where('role', isEqualTo: 'student')
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppUser.fromFirestore(d.data(), d.id))
            .toList());
  }

  // Get supervisors by department
  Stream<List<AppUser>> getSupervisorsByDepartment(String department) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'supervisor')
        .where('department', isEqualTo: department)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppUser.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<AppUser?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return AppUser.fromFirestore(data, doc.id);
    } catch (e) {
      print('❌ Error getting user by ID: $e');
      return null;
    }
  }

  Future<AppUser?> getUserByEmail(String email) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      final data = doc.data();
      return AppUser.fromFirestore(data, doc.id);
    } catch (e) {
      print('❌ Error getting user by email: $e');
      return null;
    }
  }

  // ==========
  // DEPARTMENT METHODS
  // ==========
  Future<List<String>> getDepartments() async {
    try {
      // You can maintain a separate collection for departments
      // or extract unique departments from users
      final query = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'supervisor')
          .get();

      final departments = query.docs
          .map((doc) => doc.data()['department'] as String)
          .where((dept) => dept.isNotEmpty)
          .toSet()
          .toList();

      return departments..sort();
    } catch (e) {
      print('❌ Error getting departments: $e');
      return [];
    }
  }

  // ==========
  // DEBUG METHODS
  // ==========
  Future<void> debugUserStatus(String email) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('❌ DEBUG: No user found with email: $normalizedEmail');
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      final user = AppUser.fromFirestore(data, doc.id);

      print('🔍 DEBUG User Status:');
      print('   - Document ID: ${doc.id}');
      print('   - Email: ${user.email}');
      print('   - Role: ${user.role}');
      print('   - Status: ${user.status}');
      print('   - Approved: ${user.isApproved}');
      print('   - Department: ${user.department}');
      print('   - Supervisor ID: ${user.supervisorId}');
      print('   - Created: ${user.createdAt}');
      print('   - Updated: ${user.updatedAt}');
    } catch (e) {
      print('❌ DEBUG error: $e');
    }
  }

  Future<void> debugDepartmentStats(String department) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('department', isEqualTo: department)
          .get();

      final users =
          query.docs.map((d) => AppUser.fromFirestore(d.data(), d.id)).toList();

      final students = users.where((u) => u.role == 'student').toList();
      final supervisors = users.where((u) => u.role == 'supervisor').toList();
      final pending = users.where((u) => u.status == 'pending').toList();

      print('🏢 DEBUG Department: $department');
      print('   - Total Users: ${users.length}');
      print('   - Students: ${students.length}');
      print('   - Supervisors: ${supervisors.length}');
      print('   - Pending Approvals: ${pending.length}');

      for (final supervisor in supervisors) {
        final studentCount = await _countStudentsForSupervisor(supervisor.id);
        print('   - Supervisor ${supervisor.name}: $studentCount students');
      }
    } catch (e) {
      print('❌ DEBUG department stats error: $e');
    }
  }

  // ==========
  // SIGN OUT
  // ==========
  Future<void> signOut() async {
    await _auth.signOut();
    print('👋 User signed out');
  }
}
