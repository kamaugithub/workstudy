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

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final departmentController = TextEditingController();

  String passwordStrength = "";
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // ✅ Handle user signup
  Future<void> handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    // Debug print to ensure controllers are not empty
    print('Email entered: ${emailController.text}');
    print('Password entered: ${passwordController.text}');
    print('Role selected: $selectedRole');
    print('Department: ${departmentController.text}');

    // Safety check
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all required fields."),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
      return;
    }

    try {
      // 1️⃣ Create the user in Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      // 2️⃣ Prepare user data for Firestore
      final userData = {
        'email': emailController.text.trim(),
        'role': selectedRole ?? 'Unknown',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final department = departmentController.text.trim();
      if (department.isNotEmpty) userData['department'] = department;

      // 3️⃣ Store data in Firestore under users collection
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      // ✅ Debugging confirmation
      print("User created and saved successfully in Firestore!");

      // 4️⃣ Show success message
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

        // 5️⃣ Navigate to login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // ✅ Handle Firebase-specific errors
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

      print("FirebaseAuthException: ${e.code} - ${e.message}");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      // ✅ Catch unexpected errors
      print("Unexpected signup error: $e");
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

  // ✅ Forgot Password Navigation
  void handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  // ✅ Password strength checker
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

                    // Role dropdown
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

                    // Department field
                    TextFormField(
                      controller: departmentController,
                      decoration: _inputDecoration(
                        "Department",
                        hint: "Enter your department name",
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your department";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email field
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

                    // Password field
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

                    // ✅ Sign Up Button
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
