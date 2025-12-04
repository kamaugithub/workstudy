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

  // Animation controllers for the header title
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

    // Fixed: Using direct collection path that matches the existing index
    return _firestore
        .collection('work_sessions') // Direct collection path
        .where('department', isEqualTo: supervisorDepartment)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'studentId': data['studentId'] ?? '',
                'student': data['studentName'] ?? 'Unknown Student',
                'studentEmail':
                    data['studentEmail'] ?? '', // Added student email
                'hours': data['hours'] ?? 0.0,
                'status': data['status']?.toLowerCase() ?? 'pending',
                'description': data['reportDetails'] ?? '',
                'timestamp': data['submittedAt'] as Timestamp?,
                'date': data['date'] ?? '',
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
        excel.TextCellValue("Email"),
        excel.TextCellValue("Hours"),
        excel.TextCellValue("Status"),
        excel.TextCellValue("Description"),
      ],
    ];

    for (var activity in activities) {
      data.add([
        excel.TextCellValue(activity["date"] ?? ''),
        excel.TextCellValue(activity["student"] ?? ''),
        excel.TextCellValue(
            activity["studentEmail"] ?? ''), // Added email to export
        excel.TextCellValue(activity["hours"]?.toStringAsFixed(2) ?? '0.00'),
        excel.TextCellValue(activity["status"] ?? ''),
        excel.TextCellValue(activity["description"] ?? ''),
      ]);
    }
    return data;
  }

  Future<void> _exportExcel(
      String reportType, List<Map<String, dynamic>> activities) async {
    try {
      final workbook = excel.Excel.createExcel();
      final sheet = workbook['$reportType Report'];

      // Add professional header (like in PDF)
      sheet.appendRow([excel.TextCellValue("")]);
      sheet.appendRow([excel.TextCellValue("WORKSTUDY")]);
      sheet.appendRow([excel.TextCellValue("Supervisor $reportType Report")]);

      // Get supervisor email from FirebaseAuth or fall back to supervisorName
      final supervisorEmail =
          FirebaseAuth.instance.currentUser?.email ?? supervisorName;

      sheet.appendRow([excel.TextCellValue("Generated by: $supervisorEmail")]);
      sheet.appendRow(
          [excel.TextCellValue("Department: $supervisorDepartment")]);
      sheet.appendRow([
        excel.TextCellValue(
            "Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}")
      ]);
      sheet.appendRow([]); // Empty row

      final data = _getReportData(activities);
      for (var row in data) {
        sheet.appendRow(row);
      }

      // Add summary section
      final totalHoursWorked = activities.fold(0.0, (sum, activity) {
        return sum + (activity['hours'] ?? 0.0);
      });

      sheet.appendRow([]); // Empty row
      sheet.appendRow([
        excel.TextCellValue("SUMMARY"),
        excel.TextCellValue(""),
        excel.TextCellValue(""),
        excel.TextCellValue(""),
        excel.TextCellValue(""),
        excel.TextCellValue(""),
      ]);
      sheet.appendRow([
        excel.TextCellValue("Total Activities:"),
        excel.TextCellValue(""),
        excel.TextCellValue(""),
        excel.TextCellValue(""),
        excel.TextCellValue(activities.length.toString()),
        excel.TextCellValue(""),
      ]);
      sheet.appendRow([
        excel.TextCellValue("Total Hours:"),
        excel.TextCellValue(""),
        excel.TextCellValue(""),
        excel.TextCellValue(""),
        excel.TextCellValue(totalHoursWorked.toStringAsFixed(2)),
        excel.TextCellValue(""),
      ]);

      final bytes = workbook.encode();
      if (bytes == null) return;

      final fileName =
          "workstudy_supervisor_${reportType.toLowerCase()}_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx";
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    }
  }

  Future<void> _exportPDF(
      String reportType, List<Map<String, dynamic>> activities) async {
    try {
      final pdf = pw.Document();

      // Calculate total hours
      final totalHoursWorked = activities.fold(0.0, (sum, activity) {
        return sum + (activity['hours'] ?? 0.0);
      });

      // Get supervisor email from FirebaseAuth or fall back to supervisorName
      final supervisorEmail =
          FirebaseAuth.instance.currentUser?.email ?? supervisorName;

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Section
                pw.Row(
                  children: [
                    // Logo placeholder (blue educational icon)
                    pw.Container(
                      width: 40,
                      height: 40,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue500,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          "WS",
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "WORKSTUDY",
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue700,
                          ),
                        ),
                        pw.Text(
                          "Supervisor $reportType Report",
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 15),

                // Report Info
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Generated by: $supervisorEmail",
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        "Department: $supervisorDepartment",
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        "Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}",
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Table
                pw.Text(
                  "Work Sessions - $reportType Report",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),

                pw.SizedBox(height: 10),

                // Data Table
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColors.blue700,
                  ),
                  cellStyle: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey800,
                  ),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                    5: pw.Alignment.centerLeft,
                  },
                  headers: [
                    "Date",
                    "Student",
                    "Email",
                    "Hours",
                    "Status",
                    "Description"
                  ],
                  data: activities.map((e) {
                    return [
                      e["date"] ?? '',
                      e["student"] ?? '',
                      e["studentEmail"] ?? '',
                      e["hours"]?.toStringAsFixed(2) ?? '0.00',
                      e["status"] ?? '',
                      e["description"] ?? '',
                    ];
                  }).toList(),
                ),

                pw.SizedBox(height: 15),

                // Summary
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "Total Activities:",
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                          pw.Text(
                            activities.length.toString(),
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "Total Hours:",
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                          pw.Text(
                            totalHoursWorked.toStringAsFixed(2),
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName =
          "workstudy_supervisor_${reportType.toLowerCase()}_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf";
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF export failed: $e")),
        );
      }
    }
  }

  // --- Widget Builders ---

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
    return ApprovalCardContent(
      selectedActivityTab: selectedActivityTab,
      activities: activities,
      onTabChanged: (tab) {
        setState(() {
          selectedActivityTab = tab;
        });
      },
      onApprovalChanged: handleApproval,
      primaryColor: primaryColor,
      accentColor: accentColor,
    );
  }

  Widget _buildTabButton({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
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
            // Header
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
                        FirebaseAuth.instance.signOut();
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

            // Main Content
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: getActivitiesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 50),
                            const SizedBox(height: 16),
                            Text("Error loading data:",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white)),
                            Text("${snapshot.error}",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.white70),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => setState(() {}),
                              child: Text("Retry"),
                            ),
                          ],
                        ),
                      );
                    }

                    final activities = snapshot.data ?? [];

                    final totalStudents =
                        activities.map((a) => a['studentId']).toSet().length;
                    final pendingApprovals = activities
                        .where((a) => a["status"]?.toLowerCase() == 'pending')
                        .length;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text("Welcome $supervisorName!",
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

class ApprovalCardContent extends StatefulWidget {
  final String selectedActivityTab;
  final List<Map<String, dynamic>> activities;
  final ValueChanged<String> onTabChanged;
  final Future<void> Function(String, String) onApprovalChanged;

  // Add these as parameters
  final Color primaryColor;
  final Color accentColor;

  const ApprovalCardContent({
    super.key,
    required this.selectedActivityTab,
    required this.activities,
    required this.onTabChanged,
    required this.onApprovalChanged,
    required this.primaryColor, // Added
    required this.accentColor, // Added
  });

  @override
  State<ApprovalCardContent> createState() => _ApprovalCardContentState();
}

class _ApprovalCardContentState extends State<ApprovalCardContent> {
  @override
  Widget build(BuildContext context) {
    // Filter activities based on selected tab
    final filteredActivities = widget.activities
        .where((a) =>
            a["status"]?.toLowerCase() ==
            widget.selectedActivityTab.toLowerCase())
        .toList();

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
                Icon(Icons.rule,
                    color: widget.accentColor), // Fixed: use widget.accentColor
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
                  isSelected:
                      widget.selectedActivityTab.toLowerCase() == 'pending',
                  onTap: () => widget.onTabChanged('pending'),
                ),
                _buildTabButton(
                  label: 'Approved',
                  color: Colors.green,
                  isSelected:
                      widget.selectedActivityTab.toLowerCase() == 'approved',
                  onTap: () => widget.onTabChanged('approved'),
                ),
                _buildTabButton(
                  label: 'Rejected',
                  color: Colors.red,
                  isSelected:
                      widget.selectedActivityTab.toLowerCase() == 'rejected',
                  onTap: () => widget.onTabChanged('rejected'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: filteredActivities.isEmpty
                  ? Center(
                      child: Text(
                          "No ${widget.selectedActivityTab.toLowerCase()} activities found.",
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

                        // Use student email if available, otherwise fall back to student name
                        final studentDisplay =
                            activity['studentEmail']?.isNotEmpty == true
                                ? activity['studentEmail']
                                : (activity['student'] ?? 'Unknown Student');

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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentDisplay,
                                          style: TextStyle(
                                              // Fixed: removed const
                                              fontWeight: FontWeight.bold,
                                              color: widget
                                                  .primaryColor, // Fixed: use widget.primaryColor
                                              fontSize: 14),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${activity['hours']?.toStringAsFixed(2)} hours",
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(activity['date'],
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(activity['description'],
                                  style: const TextStyle(fontSize: 14)),
                              if (widget.selectedActivityTab.toLowerCase() ==
                                  'pending')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      SizedBox(
                                        height: 30,
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              widget.onApprovalChanged(
                                                  activity['id'], 'Rejected'),
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
                                          onPressed: () =>
                                              widget.onApprovalChanged(
                                                  activity['id'], 'Approved'),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
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
  }
}
