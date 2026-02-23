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

  // ✅ Accept both Daystar AND Gmail formats
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@(daystar\.ac\.ke|gmail\.com)$',
      caseSensitive: false,
    );
    return emailRegex.hasMatch(email.trim());
  }

  // ✅ Check which domain is being used for better messaging
  String _getEmailDomain(String email) {
    if (email.toLowerCase().contains('@daystar.ac.ke')) {
      return 'Daystar';
    } else if (email.toLowerCase().contains('@gmail.com')) {
      return 'Gmail';
    }
    return 'email';
  }

  Future<void> handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final emailDomain = _getEmailDomain(email);

      if (!_isValidEmail(email)) {
        _showErrorSnackBar(
            "Please use your Daystar University email (e.g., presentations@daystar.ac.ke) or Gmail");
        return;
      }

      setState(() => isLoading = true);

      try {
        print("🔄 Attempting to send password reset email to: $email");

        await _auth.sendPasswordResetEmail(email: email);

        print("✅ Password reset email sent successfully to: $email");

        // Success - customized message based on email domain
        _showSuccessSnackBar("Password reset link sent to your $emailDomain email!");

        // Navigate to instructions page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetInstructionsPage(
              email: email,
              emailDomain: emailDomain,
            ),
          ),
        );
      } on FirebaseAuthException catch (e) {
        print("❌ Firebase Auth Error: ${e.code} - ${e.message}");
        _handleFirebaseError(e);
      } catch (e) {
        print("❌ General Error: $e");
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
        errorMessage =
            "No account found with this email. Please check if you're signed up.";
        break;
      case 'invalid-email':
        errorMessage =
            "Invalid email format. Please use a valid Daystar or Gmail email.";
        break;
      case 'too-many-requests':
        errorMessage = "Too many attempts. Please try again in a few minutes.";
        break;
      case 'network-request-failed':
        errorMessage = "Network error. Please check your internet connection.";
        break;
      case 'missing-android-pkg-name':
        errorMessage = "Android package name is missing. Contact support.";
        break;
      case 'missing-ios-bundle-id':
        errorMessage = "iOS bundle ID is missing. Contact support.";
        break;
      default:
        errorMessage =
            "Error sending reset link: ${e.message ?? 'Unknown error'}";
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
        duration: const Duration(seconds: 5),
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
        duration: const Duration(seconds: 4),
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
            // Header remains the same...
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
                            "Enter your registered email to receive reset instructions",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Email Field - Hint remains Daystar-focused
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: "Email",
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
                                return "Please enter your email";
                              }
                              if (!_isValidEmail(value)) {
                                return "Please use @daystar.ac.ke or @gmail.com email";
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

                          // Enhanced troubleshooting info
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                Text(
                                  "Check spam folder if you don't receive the email within 5 minutes.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

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