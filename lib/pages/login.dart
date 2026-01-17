import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:workstudy/pages/admindashboard.dart';
import 'package:workstudy/pages/supervisordashboard.dart';
import 'package:workstudy/pages/StudentDashboard.dart';
import '../service/auth_service.dart';
import 'signup.dart';
import 'forgot_password.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool showPassword = false;
  bool isLoading = false;

  ///  Handles login logic
  Future<void> handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter both email and password"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      //  Sign in with Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // NEW: CHECK USER APPROVAL STATUS
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.checkUserApproval(userCredential.user!.uid);

      //  Try getting user data from Firestore (your existing code)
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      // 🔍 If document doesn't exist, try finding it by email
      QuerySnapshot emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      String role;

      if (!doc.exists && emailQuery.docs.isEmpty) {
        // 🧩 Automatically create admin document if not found
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'email': email,
          'role': 'admin',
          'name': 'Admin User',
          'status': 'approved', // NEW: Set admin as approved
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

        role = 'admin';
      } else {
        final userData = doc.exists
            ? doc.data() as Map<String, dynamic>
            : emailQuery.docs.first.data() as Map<String, dynamic>;
        role = userData['role'].toString().toLowerCase();
      }

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Login Successful! Welcome $role."),
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        ),
      );

      Future.delayed(const Duration(seconds: 1), () {
        _navigateToDashboard(role);
      });
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);

      // NEW: Handle approval-specific errors
      String errorMessage;
      if (e.code == 'pending-approval') {
        errorMessage =
            'Your account is pending admin approval. Please wait for approval.';
      } else if (e.code == 'account-declined') {
        errorMessage = e.message ?? 'Your account has been declined by admin.';
      } else {
        errorMessage = e.message ?? "Login failed. Please try again.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: e.code == 'pending-approval' ? 5 : 3),
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  /// Redirect user based on role (your existing code remains same)
  void _navigateToDashboard(String role) {
    Widget targetPage;

    if (role == "admin") {
      targetPage = const AdminDashboard();
    } else if (role == "supervisor") {
      targetPage = const SupervisorDashboard();
    } else {
      targetPage = const StudentDashboard();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => targetPage),
    );
  }

  /// Navigate back to landing page
  void _goToLandingPage() {
    // Replace with your actual landing page route
    // For now, I'll use a simple pop or you can adjust based on your app structure
    Navigator.of(context).popUntil((route) => route.isFirst);
    // If you have a specific landing page, use:
    // Navigator.pushReplacementNamed(context, '/landing');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF02AEEE), Color(0xFF02AEEE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Title
                        Text(
                          "WorkStudy",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF032540),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Email Field
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: "Email Address",
                            hintText: "your.email@daystar.ac.ke",
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: const Color(0xFF032540).withOpacity(0.7),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF032540),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF032540),
                                width: 2,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        TextField(
                          controller: passwordController,
                          obscureText: !showPassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            hintText: "Enter your password",
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: const Color(0xFF032540).withOpacity(0.7),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color(0xFF032540).withOpacity(0.7),
                              ),
                              onPressed: () {
                                setState(() {
                                  showPassword = !showPassword;
                                });
                              },
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF032540),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF032540),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Forgot password?",
                              style: TextStyle(
                                color: Color(0xFF02AEEE),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Login Button
                        SizedBox(
                          width: 220,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF032540),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              elevation: 0,
                            ).copyWith(
                              overlayColor: MaterialStateProperty.all(
                                Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 25,
                                    height: 25,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w200,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // Sign Up
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: Color(0xFF032540)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignUpPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Sign up",
                                style: TextStyle(
                                  color: Color(0xFF02AEEE),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Back button at bottom navigation panel
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF02AEEE).withOpacity(0.15),
                  // Removed the white top border line
                ),
                child: Center(
                  child: Container(
                    width: 60, // Reduced size for just the icon
                    height: 60, // Reduced size for just the icon
                    decoration: BoxDecoration(
                      color: const Color(0xFF02AEEE).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(30), // Circular shape
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.0,
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _goToLandingPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 24,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
