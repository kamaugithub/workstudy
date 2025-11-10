import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:workstudy/pages/login.dart';

//import 'package:workstudy/update_users.dart';
//import 'package:workstudy/auto_create_supervisors.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const WorkStudyApp());
}

class WorkStudyApp extends StatelessWidget {
  const WorkStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Work Study',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
    );
  }
}

@override
Widget build(BuildContext context) {
  return MaterialApp(
    title: 'WorkStudy',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'Segoe UI',
      primaryColor: const Color(0xFF3b82f6),
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: const Color(0xFF3b82f6),
        secondary: const Color(0xFFfacc15),
      ),
    ),
    home: const LandingPage(),
  );
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF02AEEE), Color(0xFF02AEEE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // 🔹 Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
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

            // 🔹 Hero Section
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_rounded,
                    size: size.width * 0.3,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Track. Approve. Succeed.",
                    style: TextStyle(
                      fontSize: size.width * 0.06,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "Seamless work-study management.",
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // 🔹 CTA Button
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF032540),
                  foregroundColor: const Color.fromARGB(255, 247, 247, 248),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 55,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  elevation: 10,
                  shadowColor: Colors.black54,
                ).copyWith(
                  overlayColor: MaterialStateProperty.all(
                    Colors.white.withOpacity(0.2),
                  ),
                ),
                child: const Text(
                  "Get Started",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.normal),
                ),
              ),
            ),

            // 🔹 Footer
            Container(
              padding: const EdgeInsets.all(14),
              color: Colors.black.withOpacity(0.2),
              width: double.infinity,
              child: const Text(
                "© 2025 WorkStudy | Ramon",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
