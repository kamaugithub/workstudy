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

import 'package:workstudy/ai/ai_chat_sheet.dart';

// 🔥 GLOBAL NAVIGATOR KEY - Add this at the top
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
        // 🔥 ADD THIS LINE - Global navigator key
        navigatorKey: navigatorKey,
        
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

        // ✅ GLOBAL AI BUTTON LIVES HERE - UPDATED
        builder: (context, child) {
          return Stack(
            children: [
              child!, // entire app

              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton(
                  backgroundColor: Colors.blueAccent,
                  child: const Icon(Icons.school_outlined),
                  onPressed: () {
                    // 🔥 USE THE GLOBAL CONTEXT
                    showModalBottomSheet(
                      context: navigatorKey.currentContext!,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => const AiChatSheet(),
                    );
                  },
                ),
              ),
            ],
          );
        },

        // App entry - Changed to AuthWrapper to handle routing
        home: const AuthWrapper(),

        routes: {
          '/login': (context) => const LoginPage(),
          '/landing': (context) => const LandingPage(),
          '/admin': (context) => const AdminDashboard(),
          '/student': (context) => const StudentDashboard(),
          '/supervisor': (context) => const SupervisorDashboard(),
        },
      ),
    );
  }
}

// 🔥 LANDING PAGE (UNCHANGED)
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
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "Seamless work-study management.",
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF032540),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 55, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  "Get Started",
                  style: TextStyle(fontSize: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔥 AUTH WRAPPER (UNCHANGED) - This is now your home
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<AppUser?>(
            future: authService.getUserById(snapshot.data!.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data != null) {
                final user = userSnapshot.data!;

                if (user.isApproved) {
                  if (user.isStudent) return const StudentDashboard();
                  if (user.isSupervisor) return const SupervisorDashboard();
                  if (user.isAdmin) return const AdminDashboard();
                }
                return const PendingApprovalScreen();
              }

              return const LandingPage();
            },
          );
        }

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
          ],
        ),
      ),
    );
  }
}