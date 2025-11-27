import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'reset_instructions_page.dart';
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = false;

  // ✅ Strict Daystar email validation
  bool _isValidDaystarEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@daystar\.ac\.ke$',
      caseSensitive: false,
    );
    return emailRegex.hasMatch(email.trim());
  }

  // ✅ Real Firebase password reset
  Future<void> handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();

      if (!_isValidDaystarEmail(email)) {
        _showErrorSnackBar(
            "Please use your Daystar University email (e.g., presentations@daystar.ac.ke)");
        return;
      }

      setState(() => isLoading = true);

      try {
        await _auth.sendPasswordResetEmail(email: email);

        // Success - show confirmation
        _showSuccessSnackBar("Password reset link sent to your Daystar email!");

        // Navigate to instructions page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetInstructionsPage(email: email),
          ),
        );
      } on FirebaseAuthException catch (e) {
        _handleFirebaseError(e);
      } catch (e) {
        _showErrorSnackBar("Unexpected error: $e");
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  void _handleFirebaseError(FirebaseAuthException e) {
    String errorMessage;
    switch (e.code) {
      case 'user-not-found':
        errorMessage = "No account found with this Daystar email";
        break;
      case 'invalid-email':
        errorMessage = "Invalid email format";
        break;
      case 'too-many-requests':
        errorMessage = "Too many attempts. Please try again later";
        break;
      case 'network-request-failed':
        errorMessage = "Network error. Check your connection";
        break;
      default:
        errorMessage = "Error: ${e.message ?? 'Unknown error'}";
    }
    _showErrorSnackBar(errorMessage);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF032540),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF02AEEE), Color(0xFF02AEEE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // 🔹 Branded Header
            Padding(
              padding: const EdgeInsets.only(top: 60, bottom: 50),
              child: Text(
                "WorkStudy",
                style: TextStyle(
                  fontSize: size.width * 0.07,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      blurRadius: 8,
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
              ),
            ),

            // 🔹 Scrollable Form Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Reset Password",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF032540),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Enter your Daystar University email to receive reset instructions",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Daystar Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: "Daystar Email",
                              hintText: "e.g. presentations@daystar.ac.ke",
                              prefixIcon: const Icon(
                                Icons.school_outlined,
                                color: Color(0xFF032540),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Color(0xFF032540),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Color(0xFF032540),
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter your Daystar email";
                              }
                              if (!_isValidDaystarEmail(value)) {
                                return "Please use @daystar.ac.ke email only";
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 30),

                          // Reset Button
                          SizedBox(
                            width: 220,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : handleResetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF032540),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                elevation: 3,
                                shadowColor: Colors.black26,
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
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.send_outlined, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          "Send Reset Link",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Back to Login
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Back to Login",
                              style: TextStyle(
                                color: Color(0xFF032540),
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
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
          ],
        ),
      ),
    );
  }
}
