import 'package:flutter/material.dart';
import 'login.dart';

class ResetInstructionsPage extends StatelessWidget {
  final String email;
  final String emailDomain;
  
  const ResetInstructionsPage({
    super.key, 
    required this.email,
    this.emailDomain = 'email'
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02AEEE),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                "WorkStudy",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 70,
                        color: Color(0xFF032540),
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        "Check Your ${emailDomain == 'Daystar' ? 'Daystar' : ''} Email",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF032540),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "We've sent a password reset link to:",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF032540).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF032540).withOpacity(0.1)),
                        ),
                        child: Text(
                          email,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF032540),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        emailDomain == 'Daystar' 
                          ? "📧 Daystar emails may take longer to arrive. Check your spam folder.\n"
                            "⏰ The link will expire in 1 hour for security.\n"
                            "🔄 You'll be redirected to set a new password."
                          : "📧 Click the link in your Gmail to reset your password.\n"
                            "⏰ The link will expire in 1 hour for security.\n"
                            "🔄 You'll be redirected to set a new password.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: 220,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF032540),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            elevation: 2,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_back_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Back to Login",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Wrong email? Go back",
                          style: TextStyle(
                            color: Color(0xFF032540),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}