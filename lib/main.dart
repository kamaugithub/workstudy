import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'firebase_options.dart';
import 'package:workstudy/pages/login.dart';
import 'package:workstudy/pages/admindashboard.dart';
import 'package:workstudy/pages/studentdashboard.dart';
import 'package:workstudy/pages/supervisordashboard.dart';
import 'package:provider/provider.dart';
import 'package:workstudy/service/auth_service.dart';
import 'package:workstudy/models/user_model.dart';

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
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Work Study',
        theme: ThemeData(
          fontFamily: 'Segoe UI',
          primaryColor: const Color(0xFF3b82f6),
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: const Color(0xFF3b82f6),
            secondary: const Color(0xFFfacc15),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      //  User is imported from firebase_auth
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is logged in, check their approval status
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<AppUser?>(
            future: authService.getUserById(snapshot.data!.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (userSnapshot.hasError) {
                print('Error fetching user: ${userSnapshot.error}');
                // If there's an error, go to login
                return const LandingPage();
              }

              if (userSnapshot.hasData && userSnapshot.data != null) {
                final user = userSnapshot.data!;

                // Check if user is approved
                if (user.isApproved) {
                  // User is approved, show appropriate dashboard based on role
                  if (user.isStudent) {
                    return const StudentDashboard(); // Remove user parameter
                  } else if (user.isSupervisor) {
                    return const SupervisorDashboard(); // Remove user parameter
                  } else if (user.isAdmin) {
                    return const AdminDashboard(); // Remove user parameter
                  }
                } else {
                  // User is not approved, show pending approval screen
                  return const PendingApprovalScreen();
                }
              }

              // Fallback to landing page
              return const LandingPage();
            },
          );
        }

        // User is not logged in, show landing page
        return const LandingPage();
      },
    );
  }
}

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.orange[300]),
            const SizedBox(height: 20),
            const Text(
              'Pending Approval',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your account is waiting for administrator approval.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Provider.of<AuthService>(context, listen: false).signOut();
              },
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
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

            //  Hero Section
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

            //  CTA Button
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

            //  Footer
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
