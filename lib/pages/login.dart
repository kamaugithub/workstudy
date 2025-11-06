import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:workstudy/pages/admindashboard.dart';
import 'package:workstudy/pages/supervisordashboard.dart';
import 'package:workstudy/pages/StudentDashboard.dart';
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

  /// ✅ Handles login logic
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

      // 1️⃣ Sign in with Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // 2️⃣ Get user data from Firestore
      DocumentSnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

      if (!snapshot.exists) {
        throw Exception("User data not found");
      }

      // 3️⃣ Get and normalize role
      String role = snapshot['role'].toString().toLowerCase();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Login failed. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  /// ✅ Redirect user based on role
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
        child: Center(
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
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Color(0xFF032540),
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
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF032540),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF032540),
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
                              builder: (context) => const ForgotPasswordPage(),
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
                        child:
                            isLoading
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
      ),
    );
  }
}
