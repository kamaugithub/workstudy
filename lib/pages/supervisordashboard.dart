import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
// Assuming these helper files exist in your project structure for conditional imports
import 'package:workstudy/export_helper/save_file_other.dart';
import 'package:workstudy/export_helper/save_file_web.dart'
    if (dart.library.io) 'package:workstudy/export_helper/save_file_other.dart';
import 'package:workstudy/pages/login.dart';

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

  // Supervisor State & Data
  String selectedActivityTab = 'pending';
  final String supervisorName = "Jane Doe";
  final int totalStudents = 15;
  final int pendingApprovals = 3;

  final List<Map<String, dynamic>> allActivities = [
    {
      "id": 101,
      "date": "2024-01-15",
      "hours": 4.0,
      "status": "approved",
      "description": "Library cataloging system updates.",
      "student": "John Stone",
    },
    {
      "id": 102,
      "date": "2024-01-14",
      "hours": 3.5,
      "status": "pending",
      "description": "Computer lab hardware maintenance.",
      "student": "Alice Smith",
    },
    {
      "id": 103,
      "date": "2024-01-12",
      "hours": 5.0,
      "status": "declined",
      "description": "Student registration assistance during peak.",
      "student": "Bob Johnson",
    },
    {
      "id": 104,
      "date": "2024-01-16",
      "hours": 2.0,
      "status": "pending",
      "description": "Data entry for bursary records.",
      "student": "John Stone",
    },
    {
      "id": 105,
      "date": "2024-01-17",
      "hours": 4.5,
      "status": "approved",
      "description": "Assisted with inventory check.",
      "student": "Alice Smith",
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

  // --- Supervisor Actions ---

  void handleApproval(int activityId, String newStatus) {
    setState(() {
      final activityIndex = allActivities.indexWhere(
        (activity) => activity['id'] == activityId,
      );
      if (activityIndex != -1) {
        allActivities[activityIndex]['status'] = newStatus;
      }
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Activity $activityId $newStatus.")));
  }

  // --- Export Functions ---

  List<List<excel.CellValue>> _getReportData(String reportType) {
    // Generate data for the report
    final List<List<excel.CellValue>> data = [
      [
        excel.TextCellValue("Date"),
        excel.TextCellValue("Student"),
        excel.TextCellValue("Hours"),
        excel.TextCellValue("Status"),
        excel.TextCellValue("Description"),
      ],
    ];

    // Filter based on report type (simplified logic)
    final filteredActivities =
        allActivities.where((a) {
          if (reportType == 'Weekly') {
            // Dummy filter: only show activities from the last 7 days (or simply all in this dummy setup)
            return true;
          } else if (reportType == 'Monthly') {
            // Dummy filter: only show activities from a specific month (or simply all)
            return true;
          }
          return false;
        }).toList();

    for (var activity in filteredActivities) {
      data.add([
        excel.TextCellValue(activity["date"] ?? ''),
        excel.TextCellValue(activity["student"] ?? ''),
        excel.TextCellValue(activity["hours"]?.toString() ?? ''),
        excel.TextCellValue(activity["status"] ?? ''),
        excel.TextCellValue(activity["description"] ?? ''),
      ]);
    }
    return data;
  }

  Future<void> _exportExcel(String reportType) async {
    final workbook = excel.Excel.createExcel();
    final sheet = workbook['$reportType Report'];
    final data = _getReportData(reportType);

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _exportPDF(String reportType) async {
    final pdf = pw.Document();
    final data =
        _getReportData(
          reportType,
        ).map((row) => row.map((e) => e.value.toString()).toList()).toList();
    final headers = data.removeAt(0);

    pdf.addPage(
      pw.Page(
        build:
            (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "WorkStudy $reportType Report",
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // --- Widget Builders ---

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

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
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
                    color: primaryColor,
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

  Widget _buildApprovalCard() {
    List<Map<String, dynamic>> filteredActivities =
        allActivities
            .where((activity) => activity["status"] == selectedActivityTab)
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
                Icon(Icons.rule, color: accentColor),
                const SizedBox(width: 8),
                const Text(
                  "Student Activity Approvals",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const Divider(height: 20),

            // Tabs (Pending | Approved | Declined)
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
                  label: 'Declined',
                  color: Colors.red,
                  isSelected: selectedActivityTab == 'declined',
                  onTap: () => setState(() => selectedActivityTab = 'declined'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Activity List
            SizedBox(
              height: 300,
              child:
                  filteredActivities.isEmpty
                      ? Center(
                        child: Text(
                          "No $selectedActivityTab activities found.",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        itemCount: filteredActivities.length,
                        itemBuilder: (context, index) {
                          final activity = filteredActivities[index];
                          final statusColor =
                              activity["status"] == "approved"
                                  ? Colors.green
                                  : activity["status"] == "declined"
                                  ? Colors.red
                                  : Colors.orange;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                              ),
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
                                      "${activity['student']} (${activity['hours']}h)",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                    Text(
                                      activity['date'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  activity['description'],
                                  style: const TextStyle(fontSize: 14),
                                ),
                                if (selectedActivityTab == 'pending')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        SizedBox(
                                          height: 30,
                                          child: OutlinedButton(
                                            onPressed:
                                                () => handleApproval(
                                                  activity['id'],
                                                  'declined',
                                                ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                color: Colors.red,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                            ),
                                            child: const Text(
                                              'Decline',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          height: 30,
                                          child: ElevatedButton(
                                            onPressed:
                                                () => handleApproval(
                                                  activity['id'],
                                                  'approved',
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                            ),
                                            child: const Text(
                                              'Approve',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                              ),
                                            ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
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

  Widget _buildExportCard(
    String label,
    IconData icon,
    Color color,
    Function(String) onExportExcel,
    Function(String) onExportPDF,
  ) {
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
                Text(
                  "$label Report",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onExportExcel(label),
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
                    onPressed: () => onExportPDF(label),
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

  @override
  Widget build(BuildContext context) {
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
                        "Welcome Supervisor $supervisorName!",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Manage student work hour approvals and reports.",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),

                    // Stats Card Row
                    Row(
                      children: [
                        Expanded(
                          child: _fadeSlideIn(
                            delay: 200,
                            child: _buildStatCard(
                              "Total Students",
                              totalStudents.toString(),
                              Icons.group,
                              primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _fadeSlideIn(
                            delay: 300,
                            child: _buildStatCard(
                              "Pending Approvals",
                              pendingApprovals.toString(),
                              Icons.pending_actions,
                              Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Approval Card
                    _fadeSlideIn(delay: 400, child: _buildApprovalCard()),
                    const SizedBox(height: 20),

                    // Export Options Header
                    _fadeSlideIn(
                      delay: 500,
                      child: const Text(
                        "Export Options",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Weekly Report Export Card
                    _fadeSlideIn(
                      delay: 600,
                      child: _buildExportCard(
                        "Weekly",
                        Icons.calendar_view_week,
                        accentColor,
                        _exportExcel,
                        _exportPDF,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Monthly Report Export Card
                    _fadeSlideIn(
                      delay: 700,
                      child: _buildExportCard(
                        "Monthly",
                        Icons.calendar_month,
                        primaryColor,
                        _exportExcel,
                        _exportPDF,
                      ),
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
}
