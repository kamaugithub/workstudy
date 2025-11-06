import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workstudy/pages/login.dart';
import 'package:workstudy/pages/forgot_password.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  String? selectedRole;
  String? selectedDepartment;

  final idController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String passwordStrength = "";
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> departments = [
    "IT",
    "HR",
    "Corporate Affairs",
    "D.C.F",
    "DC3",
    "Library",
    "Sports",
    "Transport",
    "Kitchen",
  ];

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  Future<void> handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final email = emailController.text.trim();
      final idNumber = idController.text.trim();
      final password = passwordController.text.trim();
      final department = selectedDepartment ?? "Unknown";
      final role = selectedRole ?? 'Unknown';

      // Check if ID already exists
      final existing =
          await _firestore
              .collection('users')
              .where('idNumber', isEqualTo: idNumber)
              .get();

      if (existing.docs.isNotEmpty) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This ID number is already registered."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create Firebase user
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Prepare user data
      final userData = {
        'email': email,
        'idNumber': idNumber,
        'role': role,
        'department': department,
        'createdAt': FieldValue.serverTimestamp(),
        'weeklyHours': 0,
        'totalHours': 0,
        'status': 'active',
      };

      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(userCred.user!.uid)
          .set(userData);

      // Success message + redirect
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Account Created Successfully"),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 55, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF032540),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = "This email is already registered.";
          break;
        case 'weak-password':
          message = "Your password is too weak.";
          break;
        case 'invalid-email':
          message = "Invalid email address.";
          break;
        default:
          message = "Signup failed: ${e.message}";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unexpected error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  void checkPasswordStrength(String password) {
    String strength;
    final hasLetters = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumbers = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    if ((hasLetters && !hasNumbers && !hasSpecial) ||
        (!hasLetters && hasNumbers && !hasSpecial)) {
      strength = "Weak";
    } else if (hasLetters && hasNumbers && !hasSpecial) {
      strength = "Medium";
    } else if (hasLetters && hasNumbers && hasSpecial) {
      strength = "Strong";
    } else {
      strength = "Weak";
    }
    setState(() => passwordStrength = strength);
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      labelStyle: const TextStyle(color: Color(0xFF032540)),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF032540), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF032540), width: 2.0),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02AEEE),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF032540),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Role Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: _inputDecoration("Select Role"),
                      items: const [
                        DropdownMenuItem(
                          value: "Supervisor",
                          child: Text("Supervisor"),
                        ),
                        DropdownMenuItem(
                          value: "Student",
                          child: Text("Student"),
                        ),
                      ],
                      onChanged:
                          (value) => setState(() => selectedRole = value),
                      validator:
                          (value) =>
                              value == null ? "Please select a role" : null,
                    ),
                    const SizedBox(height: 16),

                    // ✅ Department Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedDepartment,
                      decoration: _inputDecoration("Department"),
                      items:
                          departments.map((dept) {
                            return DropdownMenuItem(
                              value: dept,
                              child: Text(dept),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedDepartment = value;
                        });
                      },
                      validator:
                          (value) =>
                              value == null
                                  ? "Please select your department"
                                  : null,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: emailController,
                      decoration: _inputDecoration(
                        "Email",
                        hint: "example@domain.com",
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Enter your email";
                        }
                        if (!_isValidEmail(value.trim())) {
                          return "Enter a valid email format";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ✅ ID Number Field (Manual numeric)
                    TextFormField(
                      controller: idController,
                      decoration: _inputDecoration(
                        "Unique  Number",
                        hint: "Enter assigned ID (e.g. 21-03008 or 45/456)",
                      ),
                      keyboardType: TextInputType.text, // allows -, /
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Enter your assigned number";
                        }

                        if (!RegExp(r'^[0-9\-/]+$').hasMatch(value)) {
                          return "ID must contain only numbers, dashes (-), or slashes (/)";
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      onChanged: checkPasswordStrength,
                      decoration: _inputDecoration(
                        "Password",
                        hint: "Use letters, numbers & special chars",
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: const Color(0xFF032540),
                          ),
                          onPressed:
                              () => setState(
                                () => isPasswordVisible = !isPasswordVisible,
                              ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Enter your password";
                        }
                        if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),

                    if (passwordStrength.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            "Strength: $passwordStrength",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color:
                                  passwordStrength == "Weak"
                                      ? Colors.red
                                      : passwordStrength == "Medium"
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Confirm Password
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: !isConfirmPasswordVisible,
                      decoration: _inputDecoration(
                        "Confirm Password",
                        hint: "Re-enter your password",
                        suffixIcon: IconButton(
                          icon: Icon(
                            isConfirmPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: const Color(0xFF032540),
                          ),
                          onPressed:
                              () => setState(() {
                                isConfirmPasswordVisible =
                                    !isConfirmPasswordVisible;
                              }),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Confirm your password";
                        }
                        if (value != passwordController.text) {
                          return "Passwords do not match";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: handleForgotPassword,
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Color(0xFF032540),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Submit Button
                    isLoading
                        ? const CircularProgressIndicator(
                          color: Color(0xFF032540),
                        )
                        : SizedBox(
                          width: 170,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF032540),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              elevation: 0,
                            ).copyWith(
                              overlayColor: MaterialStateProperty.all(
                                Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: const Text(
                              "Sign Up",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
