import 'dart:async';
import 'dart:typed_data';
import 'package:workstudy/export_helper/firestore_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;

import 'package:workstudy/export_helper/save_file_other.dart';
import 'package:workstudy/export_helper/save_file_web.dart'
    if (dart.library.io) 'package:workstudy/export_helper/save_file_other.dart';
import 'package:workstudy/pages/login.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with TickerProviderStateMixin {
  bool isSessionActive = false;
  String currentSessionDuration = "00:00:00";
  String comment = "";
  late Timer timer;
  DateTime startTime = DateTime.now();
  String selectedActivityTab = 'pending';

  String ID = "";
  String studentEmail = "";
  double totalHoursWorked = 0.0;
  double thisWeekHours = 0.0;

  // Change to StreamSubscription
  late StreamSubscription<List<Map<String, dynamic>>>? _activitiesSubscription;
  List<Map<String, dynamic>> studentActivities = [];

  late AnimationController _titleController;
  late Animation<double> _horizontalMovement;
  late Animation<double> _verticalMovement;

  @override
  void initState() {
    super.initState();
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _horizontalMovement = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeInOut),
    );
    _verticalMovement = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeInOut),
    );

    _loadStudentData();
    // Initialize the real-time listener
    _subscribeToActivities();
  }

  @override
  void dispose() {
    _titleController.dispose();
    if (timer.isActive) timer.cancel();
    _activitiesSubscription?.cancel(); // Cancel the subscription safely
    super.dispose();
  }

  // New method to subscribe to live data
  void _subscribeToActivities() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      print('❌ No valid user ID for activities subscription');
      return;
    }

    try {
      // Use FirestoreHelper to get a stream of student's activities
      _activitiesSubscription = FirestoreHelper.getStudentWorkSessionsStream(
        user.uid,
      ).listen(
        (sessions) {
          // Recalculate totals on every update
          _calculateHours(sessions);

          // Update the main list for the Activity Card
          if (mounted) {
            setState(() {
              // Sort sessions by timestamp descending (most recent first)
              sessions.sort(
                (a, b) => (b['submittedAt'] as Timestamp? ?? Timestamp.now())
                    .compareTo(
                        a['submittedAt'] as Timestamp? ?? Timestamp.now()),
              );

              studentActivities = sessions
                  .map(
                    (doc) => {
                      "date": doc['date'] ?? '',
                      "hours": doc['hours'] ?? 0.0,
                      "status": doc['status'] ?? '',
                      "description":
                          doc['reportDetails'] ?? '', // Updated field name
                      "timestamp": doc['submittedAt'], // Updated field name
                    },
                  )
                  .toList();
            });
          }
        },
        onError: (error) {
          // Handle error
          print("Error fetching activities stream: $error");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Error loading activities: $error"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      print('❌ Error setting up activities subscription: $e');
    }
  }

  // Combine hour calculation logic into a single function to be called by both _loadStudentData and _subscribeToActivities
  void _calculateHours(List<Map<String, dynamic>> sessions) {
    double total = 0.0;
    double weekTotal = 0.0;
    final now = DateTime.now();

    for (var session in sessions) {
      final hours = session['hours'] ?? 0.0; // Now it's a number, not string
      total += hours;

      // Calculate week total based on submittedAt timestamp
      final submittedAt = session['submittedAt'] as Timestamp?;
      if (submittedAt != null) {
        final date = submittedAt.toDate();
        if (date.isAfter(now.subtract(const Duration(days: 7)))) {
          weekTotal += hours;
        }
      }
    }

    if (mounted) {
      setState(() {
        totalHoursWorked = total;
        thisWeekHours = weekTotal;
      });
    }
  }

  Future<void> _loadStudentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Use FirestoreHelper to get user profile
      final userData = await FirestoreHelper.getUserProfile(user.uid);
      if (userData == null) return;

      if (mounted) {
        setState(() {
          ID = userData['ID'] ?? "";
          studentEmail = userData['email'] ?? user.email ?? "";
        });
      }
    } catch (e) {
      print('❌ Error loading student data: $e');
    }
  }

  void handleClockIn() {
    setState(() {
      isSessionActive = true;
      startTime = DateTime.now();
      currentSessionDuration = "00:00:00";
    });
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() {
          final duration = DateTime.now().difference(startTime);
          currentSessionDuration = formatDuration(duration);
        });
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Session Started. Don't forget to clock out!"),
      ),
    );
  }

  void handleClockOut() {
    if (timer.isActive) timer.cancel();
    if (mounted) {
      setState(() {
        isSessionActive = false;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Session Ended. Add description and submit."),
      ),
    );
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  // IMPROVED: Calculate hours with better precision and include student email
  Future<void> handleSubmitHours() async {
    if (comment.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please describe your work before submitting."),
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Use FirestoreHelper to get user profile
      final userData = await FirestoreHelper.getUserProfile(user.uid);
      if (userData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error: User profile not found."),
          ),
        );
        return;
      }

      final studentDepartment = userData['department'];
      final studentName = userData['name'] ?? "";

      // Get current email (use stored email or Firebase auth email as fallback)
      final currentStudentEmail =
          studentEmail.isNotEmpty ? studentEmail : user.email ?? "";

      // IMPROVED: Calculate hours with better precision from duration
      final parts = currentSessionDuration.split(':');
      double hours = 0.0;
      if (parts.length == 3) {
        final totalSeconds = (int.parse(parts[0]) * 3600) + // hours to seconds
            (int.parse(parts[1]) * 60) + // minutes to seconds
            int.parse(parts[2]); // seconds

        // Convert to hours with 2 decimal places for better precision
        hours = double.parse((totalSeconds / 3600).toStringAsFixed(2));
      }

      // IMPROVED: Save work session with student email and name
      await FirestoreHelper.addWorkSession({
        'studentId': user.uid,
        'studentName': studentName, // Added student name
        'studentEmail': currentStudentEmail, // Added student email
        'department': studentDepartment,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'hours': hours, // Store as precise decimal number
        'reportDetails': comment.trim(),
        'status': 'Pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          comment = "";
          isSessionActive = false;
          currentSessionDuration = "00:00:00";
        });
      }

      if (timer.isActive) timer.cancel();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$hours hours submitted for supervisor approval."),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting hours: $e")),
      );
    }
  }

  // Updated to use FirestoreHelper.getAllWorkSessions()
  Future<void> exportExcel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Fetch live data for export
      final sessions = await FirestoreHelper.getAllWorkSessions(user.uid);

      final workbook = excel.Excel.createExcel();
      final sheet = workbook['Report'];
      sheet.appendRow([
        excel.TextCellValue("Date"),
        excel.TextCellValue("Hours"),
        excel.TextCellValue("Status"),
        excel.TextCellValue("Description"),
      ]);

      for (var session in sessions) {
        sheet.appendRow([
          excel.TextCellValue(session["date"] ?? ''),
          excel.TextCellValue(session["hours"]?.toStringAsFixed(2) ?? '0.00'),
          excel.TextCellValue(session["status"] ?? ''),
          excel.TextCellValue(session["reportDetails"] ?? ''),
        ]);
      }

      final bytes = workbook.encode();
      if (bytes == null) return;

      const fileName = "workstudy_report.xlsx";
      String message;

      if (kIsWeb) {
        saveFileWeb(Uint8List.fromList(bytes), fileName);
        message = "✅ Excel file download initiated.";
      } else {
        final path = await saveFileOther(Uint8List.fromList(bytes), fileName);
        message = "✅ Excel exported to: $path";
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting Excel: $e")),
        );
      }
    }
  }

  // Updated to use FirestoreHelper.getAllWorkSessions()
  Future<void> exportPDF() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Fetch live data for export
      final sessions = await FirestoreHelper.getAllWorkSessions(user.uid);

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "WorkStudy Report",
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ["Date", "Hours", "Status", "Description"],
                data: sessions.map((e) {
                  return [
                    e["date"] ?? '',
                    e["hours"]?.toStringAsFixed(2) ?? '0.00',
                    e["status"] ?? '',
                    e["reportDetails"] ?? '',
                  ];
                }).toList(),
              ),
            ],
          ),
        ),
      );

      final bytes = await pdf.save();
      const fileName = "workstudy_report.pdf";
      String message;

      if (kIsWeb) {
        saveFileWeb(bytes, fileName);
        message = "✅ PDF file download initiated.";
      } else {
        final path = await saveFileOther(bytes, fileName);
        message = "✅ PDF exported to: $path";
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting PDF: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF032540);
    const accentColor = Color(0xFF02AEEE);

    return Scaffold(
      backgroundColor: accentColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: accentColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: AnimatedBuilder(
                      animation: _titleController,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          _horizontalMovement.value,
                          _verticalMovement.value,
                        ),
                        child: const Text(
                          "WorkStudy",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: "Logout",
                      onPressed: () {
                        FirebaseAuth.instance.signOut();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _fadeSlideIn(
                      delay: 100,
                      child: Text(
                        "Hello $ID 👋",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Ready to track your work hours today?",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _fadeSlideIn(
                            delay: 200,
                            child: _buildStatCard(
                              "Total Hours",
                              totalHoursWorked.toStringAsFixed(1),
                              Icons.timer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _fadeSlideIn(
                            delay: 300,
                            child: _buildStatCard(
                              "This Week",
                              thisWeekHours.toStringAsFixed(1),
                              Icons.trending_up,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _fadeSlideIn(
                      delay: 400,
                      child: _buildClockCard(primaryColor, accentColor),
                    ),
                    const SizedBox(height: 20),
                    _fadeSlideIn(
                      delay: 500,
                      child: _buildCommentCard(primaryColor, accentColor),
                    ),
                    const SizedBox(height: 20),
                    _fadeSlideIn(
                      delay: 600,
                      child: _buildActivityCard(primaryColor, accentColor),
                    ),
                    const SizedBox(height: 20),
                    _fadeSlideIn(
                      delay: 700,
                      child: _buildExportCard(primaryColor, accentColor),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fadeSlideIn({required int delay, required Widget child}) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + delay),
      curve: Curves.easeOut,
      builder: (context, value, _) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF02AEEE).withOpacity(0.15),
              child: Icon(icon, color: const Color(0xFF02AEEE)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF032540),
                  ),
                ),
                Text(label, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockCard(Color primaryColor, Color accentColor) {
    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: accentColor),
                const SizedBox(width: 8),
                const Text(
                  "Current Session",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isSessionActive
                  ? "Session in progress..."
                  : "Start a new work session",
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            if (isSessionActive)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Session Duration",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentSessionDuration,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: "monospace",
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "(${_calculateCurrentHours()} hours)",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isSessionActive ? handleClockOut : handleClockIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSessionActive ? Colors.red : primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 17,
                ),
              ),
              icon: Icon(
                isSessionActive ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
              ),
              label: Text(
                isSessionActive ? "Clock Out" : "Clock In",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to calculate current hours for display
  String _calculateCurrentHours() {
    final parts = currentSessionDuration.split(':');
    if (parts.length == 3) {
      final totalSeconds = (int.parse(parts[0]) * 3600) +
          (int.parse(parts[1]) * 60) +
          int.parse(parts[2]);
      return (totalSeconds / 3600).toStringAsFixed(2);
    }
    return "0.00";
  }

  Widget _buildCommentCard(Color primaryColor, Color accentColor) {
    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Work Description",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Describe the work you've done",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              maxLines: 3,
              onChanged: (val) => setState(() => comment = val),
              decoration: InputDecoration(
                hintText: "Describe your work...",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: handleSubmitHours,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 17,
                  ),
                ),
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text(
                  "Submit Hours for Approval",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Color primaryColor, Color accentColor) {
    // Uses the new `studentActivities` list which is updated via the stream
    List<Map<String, dynamic>> filteredActivities = studentActivities
        .where((activity) =>
            activity["status"]?.toLowerCase() == selectedActivityTab)
        .toList();

    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.history, color: accentColor),
                const SizedBox(width: 8),
                const Text(
                  "Recent Activities",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabButton(
                  label: 'Pending',
                  color: Colors.orange,
                  isSelected: selectedActivityTab == 'pending',
                  onTap: () => setState(() => selectedActivityTab = 'pending'),
                ),
                _buildTabButton(
                  label: 'Approved',
                  color: Colors.green,
                  isSelected: selectedActivityTab == 'approved',
                  onTap: () => setState(() => selectedActivityTab = 'approved'),
                ),
                _buildTabButton(
                  label: 'Rejected',
                  color: Colors.red,
                  isSelected: selectedActivityTab == 'declined',
                  onTap: () => setState(() => selectedActivityTab = 'declined'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: filteredActivities.isEmpty
                  ? Center(
                      child: Text(
                        "No $selectedActivityTab activities available",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredActivities.length,
                      itemBuilder: (context, index) {
                        final activity = filteredActivities[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          activity["date"],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: activity["status"]
                                                        ?.toLowerCase() ==
                                                    "approved"
                                                ? Colors.green
                                                : activity["status"]
                                                            ?.toLowerCase() ==
                                                        "rejected"
                                                    ? Colors.red
                                                    : Colors.orange,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            activity["status"] ?? 'Pending',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      activity["description"] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF032540),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "${activity["hours"]?.toStringAsFixed(1)}h",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF032540),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? color : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildExportCard(Color primaryColor, Color accentColor) {
    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Export Reports",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: exportExcel,
                    icon: const Icon(Icons.table_chart, color: Colors.green),
                    label: const Text(
                      "Export Excel",
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: exportPDF,
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    label: const Text(
                      "Export PDF",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
