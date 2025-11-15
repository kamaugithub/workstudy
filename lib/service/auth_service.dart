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

      // Check email exists
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
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

      // Create Firebase user
      UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      print('✅ Firebase account created: $uid');

      // Auto assign supervisor for student
      String? supervisorId;
      if (role.toLowerCase() == 'student') {
        supervisorId = await _findSupervisorForDepartment(department);
      }

      final name = _generateNameFromEmail(email);

      final newUser = AppUser(
        id: uid,
        email: email,
        name: name,
        role: role,
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

      print('🎉 Signup completed for $email');
      return newUser;
    } catch (e) {
      print('❌ Signup error: $e');
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
          .map((w) =>
              w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
          .join(' ');
    } catch (_) {
      return 'User';
    }
  }

  // ====================
  // SIGN IN WITH CHECKS
  // ====================
  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Signing in $email');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        print('⚠ No user doc found by UID, searching by email...');
        final query = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          userDoc = query.docs.first;
        } else {
          // auto-create admin fallback
          if (email.contains('admin')) {
            final name = _generateNameFromEmail(email);
            final admin = AppUser(
              id: uid,
              email: email,
              name: name,
              role: 'admin',
              department: 'Administration',
              status: 'approved',
              totalHours: 0,
              weeklyHours: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _firestore
                .collection('users')
                .doc(uid)
                .set(admin.toFirestore());
            return admin;
          }
          return null;
        }
      }

      final data = userDoc.data();
      if (data == null) return null;

      final user =
          AppUser.fromFirestore(data as Map<String, dynamic>, userDoc.id);

      // Approval check
      if (!user.isApproved) {
        await _auth.signOut();

        if (user.isDeclined) {
          throw FirebaseAuthException(
            code: 'account-declined',
            message: user.rejectionReason ??
                'Your account has been declined.',
          );
        }

        throw FirebaseAuthException(
          code: 'pending-approval',
          message: 'Your account is pending approval.',
        );
      }

      print('✅ Login successful for ${user.email}');
      return user;
    } catch (e) {
      print('❌ Signin error: $e');
      rethrow;
    }
  }

  // =============================
  // SUPERVISOR AUTO-ASSIGN SEARCH
  // =============================
  Future<String?> _findSupervisorForDepartment(String department) async {
    try {
      if (department.isEmpty) return null;

      final query = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'supervisor')
          .where('department', isEqualTo: department)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      return query.docs.first.id;
    } catch (e) {
      print('❌ Supervisor search error: $e');
      return null;
    }
  }

  // ===============================
  // FIXED APPROVAL CHECK (THE ISSUE)
  // ===============================
  Future<void> checkUserApproval(String userId) async {
    try {
      print('🔍 Checking approval for $userId');

      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        print('❌ No user doc found during approval check');
        return;
      }

      final data = doc.data();
      if (data == null) return;

      final user =
          AppUser.fromFirestore(data as Map<String, dynamic>, doc.id);

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
    } catch (e) {
      print('❌ Approval check error: $e');
      rethrow;
    }
  }

  // =============
  // ADMIN ACTIONS
  // =============
  Future<void> approveUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'status': 'approved',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'rejectionReason': FieldValue.delete(),
    });
  }

  Future<void> declineUser(String userId, String reason) async {
    await _firestore.collection('users').doc(userId).update({
      'status': 'declined',
      'rejectionReason': reason,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // =============
  // GET USERS
  // =============
  Stream<List<AppUser>> getPendingUsers() {
    return _firestore
        .collection('users')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppUser.fromFirestore(d.data(), d.id)).toList());
  }

  Stream<List<AppUser>> getAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppUser.fromFirestore(d.data(), d.id)).toList());
  }

  Future<AppUser?> getUserById(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return AppUser.fromFirestore(data, doc.id);
  }

  // ==========
  // SIGN OUT
  // ==========
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
