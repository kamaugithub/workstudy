import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workstudy/export_helper/save_file_other.dart';
import 'package:workstudy/export_helper/save_file_web.dart'
    if (dart.library.io) 'package:workstudy/export_helper/save_file_other.dart';
import 'package:workstudy/pages/login.dart';
import 'package:workstudy/export_helper/firestore_helper.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard>
    with TickerProviderStateMixin {
  // Theme Colors
  static const primaryColor = Color(0xFF032540);
  static const accentColor = Color(0xFF02AEEE);

  // Supervisor State
  String selectedActivityTab = 'pending';
  String supervisorName = "";
  String supervisorDepartment = "";

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Animation controllers for the header title (KEPT as requested)
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

    _loadSupervisorData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadSupervisorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userData = await FirestoreHelper.getUserProfile(user.uid);
    if (userData == null) return;

    setState(() {
      supervisorName = userData['name'] ?? "";
      supervisorDepartment = userData['department'] ?? "";
    });
  }

  // --- Firestore Helpers ---
  Stream<List<Map<String, dynamic>>> getActivitiesStream() {
    if (supervisorDepartment.isEmpty) {
      return Stream.value([]);
    }

    // Updated to match your Firestore structure and security rules
    return _firestore
        .collection('artifacts')
        .doc('workstudy-bcda5')
        .collection('public/data/work_sessions')
        .where('department',
            isEqualTo:
                supervisorDepartment) // Filter by supervisor's department
        .orderBy('submittedAt', descending: true) // Updated field name
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'studentId': data['studentId'] ?? '',
                'student': data['studentName'] ??
                    'Unknown Student', // You might want to fetch student name separately
                'hours': data['hours'] ?? 0.0, // Now a number
                'status': data['status']?.toLowerCase() ??
                    'pending', // Ensure lowercase for filtering
                'description':
                    data['reportDetails'] ?? '', // Updated field name
                'timestamp':
                    data['submittedAt'] as Timestamp?, // Updated field name
                'date': data['date'] ?? '', // Use the stored date field
                'department': data['department'] ?? '',
              };
            }).toList());
  }

  Future<void> handleApproval(String activityId, String newStatus) async {
    try {
      // Use FirestoreHelper for consistency
      await FirestoreHelper.updateWorkSessionStatus(activityId, newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Activity $newStatus.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update activity: $e")),
        );
      }
    }
  }

  // --- Export Functions ---
  List<List<excel.CellValue>> _getReportData(
      List<Map<String, dynamic>> activities) {
    final data = [
      [
        excel.TextCellValue("Date"),
        excel.TextCellValue("Student"),
        excel.TextCellValue("Hours"),
        excel.TextCellValue("Status"),
        excel.TextCellValue("Description"),
      ],
    ];

    for (var activity in activities) {
      data.add([
        excel.TextCellValue(activity["date"] ?? ''),
        excel.TextCellValue(activity["student"] ?? ''),
        excel.TextCellValue(activity["hours"]?.toStringAsFixed(2) ?? '0.00'),
        excel.TextCellValue(activity["status"] ?? ''),
        excel.TextCellValue(activity["description"] ?? ''),
      ]);
    }
    return data;
  }

  Future<void> _exportExcel(
      String reportType, List<Map<String, dynamic>> activities) async {
    final workbook = excel.Excel.createExcel();
    final sheet = workbook['$reportType Report'];
    final data = _getReportData(activities);

    for (var row in data) {
      sheet.appendRow(row);
    }

    final bytes = workbook.encode();
    if (bytes == null) return;

    final fileName =
        "workstudy_supervisor_${reportType.toLowerCase()}_report.xlsx";
    String message;

    if (kIsWeb) {
      saveFileWeb(Uint8List.fromList(bytes), fileName);
      message = "✅ $reportType Excel download initiated.";
    } else {
      final path = await saveFileOther(Uint8List.fromList(bytes), fileName);
      message = "✅ $reportType Excel exported to: $path";
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _exportPDF(
      String reportType, List<Map<String, dynamic>> activities) async {
    final pdf = pw.Document();
    final data = _getReportData(activities)
        .map((row) => row.map((e) => e.toString()).toList())
        .toList();
    final headers = data.removeAt(0);

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "WorkStudy $reportType Report",
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(headers: headers, data: data),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    final fileName =
        "workstudy_supervisor_${reportType.toLowerCase()}_report.pdf";
    String message;

    if (kIsWeb) {
      saveFileWeb(bytes, fileName);
      message = "✅ $reportType PDF download initiated.";
    } else {
      final path = await saveFileOther(bytes, fileName);
      message = "✅ $reportType PDF exported to: $path";
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // --- Widget Builders (No animations in the main content) ---

  Widget _buildStatCard(
      String label, String value, IconData icon, Color iconColor) {
    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.15),
              child: Icon(icon, color: iconColor),
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
                      color: primaryColor),
                ),
                Text(label, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalCard(List<Map<String, dynamic>> activities) {
    final filteredActivities =
        activities.where((a) => a["status"] == selectedActivityTab).toList();

    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rule, color: accentColor),
                const SizedBox(width: 8),
                const Text("Student Activity Approvals",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(height: 20),
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
                  isSelected: selectedActivityTab == 'rejected',
                  onTap: () => setState(() => selectedActivityTab = 'rejected'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: filteredActivities.isEmpty
                  ? Center(
                      child: Text("No $selectedActivityTab activities found.",
                          style: const TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filteredActivities.length,
                      itemBuilder: (context, index) {
                        final activity = filteredActivities[index];
                        final statusColor = activity["status"] == "approved"
                            ? Colors.green
                            : activity["status"] == "rejected"
                                ? Colors.red
                                : Colors.orange;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: statusColor.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      "${activity['student']} (${activity['hours']?.toStringAsFixed(1)}h)",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor)),
                                  Text(activity['date'],
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(activity['description'],
                                  style: const TextStyle(fontSize: 14)),
                              if (selectedActivityTab == 'pending')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      SizedBox(
                                        height: 30,
                                        child: OutlinedButton(
                                          onPressed: () => handleApproval(
                                              activity['id'],
                                              'Rejected'), // Capitalized to match security rules
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(
                                                color: Colors.red),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                          ),
                                          child: const Text('Reject',
                                              style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 30,
                                        child: ElevatedButton(
                                          onPressed: () => handleApproval(
                                              activity['id'],
                                              'Approved'), // Capitalized to match security rules
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                          ),
                                          child: const Text('Approve',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white)),
                                        ),
                                      ),
                                    ],
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
    // --- MODIFICATION: Removed GestureDetector, using ClipRRect + InkWell for static interaction ---
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        splashColor: color.withOpacity(0.2), // Subtle splash without animation
        highlightColor:
            color.withOpacity(0.1), // Subtle highlight without animation
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
            border: isSelected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : Colors.grey.shade600)),
        ),
      ),
    );
    // --- END MODIFICATION ---
  }

  Widget _buildExportCard(String label, IconData icon, Color color,
      List<Map<String, dynamic>> activities) {
    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text("$label Report",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportExcel(label, activities),
                    icon: const Icon(Icons.table_chart, color: Colors.green),
                    label: const Text("Export Excel",
                        style: TextStyle(color: Colors.green)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportPDF(label, activities),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    label: const Text("Export PDF",
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: accentColor,
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Fixed Animated Header (Animation is KEPT here)
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: accentColor,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2))
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: AnimatedBuilder(
                      animation: _titleController,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                            _horizontalMovement.value, _verticalMovement.value),
                        child: const Text(
                          "WorkStudy",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
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
                        // NOTE: In a real app, this should involve Firebase sign-out
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginPage()));
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 Scrollable Content (Animations REMOVED)
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: getActivitiesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }

                    final activities = snapshot.data ?? [];

                    final totalStudents =
                        activities.map((a) => a['student']).toSet().length;
                    final pendingApprovals = activities
                        .where((a) => a["status"] == 'pending')
                        .length;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          // Static content starts here (no animation wrapper)
                          Text("Welcome Supervisor $supervisorName!",
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor)),
                          const SizedBox(height: 4),
                          const Text(
                              "Manage student work hour approvals and reports.",
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildStatCard(
                                      "Total Students",
                                      totalStudents.toString(),
                                      Icons.group,
                                      primaryColor)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _buildStatCard(
                                      "Pending Approvals",
                                      pendingApprovals.toString(),
                                      Icons.pending_actions,
                                      Colors.orange)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildApprovalCard(activities),
                          const SizedBox(height: 20),
                          const Text("Export Options",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor)),
                          const SizedBox(height: 12),
                          _buildExportCard("Weekly", Icons.calendar_view_week,
                              accentColor, activities),
                          const SizedBox(height: 12),
                          _buildExportCard("Monthly", Icons.calendar_month,
                              primaryColor, activities),
                          const SizedBox(height: 40),
                        ],
                      ),
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
