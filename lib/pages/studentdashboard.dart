import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
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

  final String studentName = "John Stone";
  final double totalHoursWorked = 48.5;
  final double thisWeekHours = 12.5;

  final List<Map<String, dynamic>> recentActivities = [
    {
      "date": "2024-01-15",
      "hours": 4,
      "status": "approved",
      "description": "Library cataloging",
    },
    {
      "date": "2024-01-14",
      "hours": 3.5,
      "status": "pending",
      "description": "Computer lab maintenance",
    },
    {
      "date": "2024-01-12",
      "hours": 5,
      "status": "declined",
      "description": "Student registration assistance",
    },
  ];

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
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void handleClockIn() {
    setState(() => isSessionActive = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Session Started. Don't forget to clock out!"),
      ),
    );
  }

  void handleClockOut() {
    setState(() {
      isSessionActive = false;
      currentSessionDuration = "00:00:00";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Session Ended. Add description and submit."),
      ),
    );
  }

  void handleSubmitHours() {
    if (comment.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please describe your work before submitting."),
        ),
      );
      return;
    }
    setState(() => comment = "");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Hours Submitted for Supervisor Approval.")),
    );
  }

  // ✅ EXPORT EXCEL
Future<void> exportExcel() async {
    final workbook = excel.Excel.createExcel();
    final sheet = workbook['Report'];

    // ✅ Add header row (must use CellValue objects)
    sheet.appendRow([
      excel.TextCellValue("Date"),
      excel.TextCellValue("Hours"),
      excel.TextCellValue("Status"),
      excel.TextCellValue("Description"),
    ]);

    // ✅ Add data rows
    for (var activity in recentActivities) {
      sheet.appendRow([
        excel.TextCellValue(activity["date"] ?? ''),
        excel.TextCellValue(activity["hours"]?.toString() ?? ''),
        excel.TextCellValue(activity["status"] ?? ''),
        excel.TextCellValue(activity["description"] ?? ''),
      ]);
    }

    // ✅ Save the file
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/workstudy_report.xlsx";
    final bytes = workbook.encode();

    if (bytes != null) {
      final file = File(path);
      file.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("✅ Excel exported to: $path")));
  }

  // ✅ EXPORT PDF
  Future<void> exportPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build:
            (context) => pw.Column(
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
                  data:
                      recentActivities.map((e) {
                        return [
                          e["date"] ?? '',
                          e["hours"].toString(),
                          e["status"] ?? '',
                          e["description"] ?? '',
                        ];
                      }).toList(),
                ),
              ],
            ),
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/workstudy_report.pdf";
    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("✅ PDF exported to: $path")));
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
            // 🔹 Fixed Animated Header
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
                      builder: (context, child) {
                        return Transform.translate(
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
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: "Logout",
                      onPressed: () {
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

            // 🔹 Scrollable Content
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
                        "Hello $studentName 👋",
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
                              totalHoursWorked.toString(),
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
                              thisWeekHours.toString(),
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
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
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
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isSessionActive ? handleClockOut : handleClockIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSessionActive ? Colors.red : primaryColor,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
            ElevatedButton.icon(
              onPressed: comment.trim().isEmpty ? null : handleSubmitHours,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text(
                "Submit Hours for Approval",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Color primaryColor, Color accentColor) {
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
            Column(
              children:
                  recentActivities.map((activity) {
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
                                        color:
                                            activity["status"] == "approved"
                                                ? Colors.green
                                                : activity["status"] ==
                                                    "declined"
                                                ? Colors.red
                                                : Colors.orange,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        activity["status"],
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
                                  activity["description"],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF032540),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "${activity["hours"]}h",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF032540),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ],
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
