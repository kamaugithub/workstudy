import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:workstudy/pages/login.dart';
import 'package:workstudy/pages/forgot_password.dart';
import '../service/auth_service.dart';

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

  // ✅ Accept both Daystar AND Gmail formats
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@(daystar\.ac\.ke|gmail\.com)$',
      caseSensitive: false,
    );
    return emailRegex.hasMatch(email.trim());
  }

  // ✅ Get email domain for better messaging
  String _getEmailDomain(String email) {
    if (email.toLowerCase().contains('@daystar.ac.ke')) {
      return 'Daystar';
    } else if (email.toLowerCase().contains('@gmail.com')) {
      return 'Gmail';
    }
    return 'email';
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
      final emailDomain = _getEmailDomain(email);

      // Check if ID already exists
      final existing = await _firestore
          .collection('users')
          .where('idNumber', isEqualTo: idNumber)
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This ID number is already registered."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Create Firebase user using AuthService
      final authService = Provider.of<AuthService>(context, listen: false);

      await authService.signUp(
        email: email,
        password: password,
        role: role,
        department: department,
        idNumber: idNumber,
      );

      // Success message with approval notice
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Registration Successful'),
            content: Text(
              'Your $emailDomain account has been created and is pending admin approval. '
              'You will be able to login once approved. '
              'Thank you.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      String message;
      switch (e.code) {
        case 'email-already-in-use':
        case 'email-already-exists':
          message = "This email is already registered.";
          break;
        case 'id-already-exists':
          message = "This ID number is already registered.";
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unexpected error: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      labelStyle: const TextStyle(color: Color(0xFF032540)),
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF032540), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF032540), width: 2.0),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  void dispose() {
    idController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
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
                    // WorkStudy Logo/Title
                    const Text(
                      "WorkStudy",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF032540),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 22,
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
                      onChanged: (value) =>
                          setState(() => selectedRole = value),
                      validator: (value) =>
                          value == null ? "Please select a role" : null,
                    ),
                    const SizedBox(height: 16),

                    // Department Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedDepartment,
                      decoration: _inputDecoration("Department"),
                      items: departments.map((dept) {
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
                      validator: (value) => value == null
                          ? "Please select your department"
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Email Field with Daystar-focused hint
                    TextFormField(
                      controller: emailController,
                      decoration: _inputDecoration(
                        "Email Address",
                        hint: "e.g. present@daystar.ac.ke or present@gmail.com",
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Color(0xFF032540),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your email";
                        }
                        if (!_isValidEmail(value.trim())) {
                          return "Please use @daystar.ac.ke or @gmail.com email";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ID Number Field
                    TextFormField(
                      controller: idController,
                      decoration: _inputDecoration(
                        "ID Number",
                        hint:
                            "Enter assigned ID number (e.g. 21-03008 or 45/456)",
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: Color(0xFF032540),
                        ),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Enter your ID number";
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
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF032540),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: const Color(0xFF032540),
                          ),
                          onPressed: () => setState(
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

                    // Password Strength Indicator
                    if (passwordStrength.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            "Strength: $passwordStrength",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: passwordStrength == "Weak"
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
                        prefixIcon: const Icon(
                          Icons.lock_reset_outlined,
                          color: Color(0xFF032540),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isConfirmPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: const Color(0xFF032540),
                          ),
                          onPressed: () => setState(() {
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

                    // Email Domain Note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF032540).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF032540).withOpacity(0.1),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Use an active email for registration.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: handleForgotPassword,
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Color(0xFF032540),
                            fontWeight: FontWeight.w500,
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
                            width: 200,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: handleSignUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF032540),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                elevation: 3,
                                shadowColor: Colors.black26,
                              ).copyWith(
                                overlayColor: MaterialStateProperty.all(
                                  Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_add_alt_1, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "Create Account",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                    // Already have account
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(color: Color(0xFF032540)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LoginPage()),
                            );
                          },
                          child: const Text(
                            "Login Here",
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
