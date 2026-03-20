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
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
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
  Timer? timer;
  DateTime startTime = DateTime.now();
  DateTime? clockInTime;
  DateTime? clockOutTime;
  String selectedActivityTab = 'pending';

  String ID = "";
  String studentEmail = "";
  String studentDepartment = "";
  String studentName = "";
  double totalHoursWorked = 0.0;
  double thisWeekHours = 0.0;

  StreamSubscription<List<Map<String, dynamic>>>? _activitiesSubscription;
  List<Map<String, dynamic>> studentActivities = [];

  late AnimationController _titleController;
  late Animation<double> _horizontalMovement;
  late Animation<double> _verticalMovement;
  
  Timer? _draftSaveTimer;
  String _draftDescription = "";

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
    _subscribeToActivities();
    _loadDraftDescription();
  }

  @override
  void dispose() {
    _titleController.dispose();
    timer?.cancel();
    _draftSaveTimer?.cancel();
    _activitiesSubscription?.cancel();
    _saveDraftDescription();
    super.dispose();
  }

  void _loadDraftDescription() {
    setState(() {
      comment = _draftDescription;
    });
  }

  void _saveDraftDescription() {
    if (comment.trim().isNotEmpty) {
      _draftDescription = comment;
    }
  }

  void _subscribeToActivities() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      print('❌ No valid user ID for activities subscription');
      return;
    }

    try {
      _activitiesSubscription = FirestoreHelper.getStudentWorkSessionsStream(
        user.uid,
      ).listen(
        (sessions) {
          _calculateHours(sessions);
          if (mounted) {
            setState(() {
              sessions.sort(
                (a, b) => (b['submittedAt'] as Timestamp? ?? Timestamp.now())
                    .compareTo(
                        a['submittedAt'] as Timestamp? ?? Timestamp.now()),
              );

              studentActivities = sessions
                  .map(
                    (doc) => {
                      "date": doc['date'] ?? '',
                      "clockIn": doc['clockIn'] != null 
                          ? (doc['clockIn'] as Timestamp).toDate() 
                          : null,
                      "clockOut": doc['clockOut'] != null 
                          ? (doc['clockOut'] as Timestamp).toDate() 
                          : null,
                      "hours": doc['hours'] ?? 0.0,
                      "status": doc['status'] ?? '',
                      "description": doc['reportDetails'] ?? '',
                      "timestamp": doc['submittedAt'],
                      "feedback": doc['feedback'] ?? '',
                    },
                  )
                  .toList();
            });
          }
        },
        onError: (error) {
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

  void _calculateHours(List<Map<String, dynamic>> sessions) {
    double total = 0.0;
    double weekTotal = 0.0;
    final now = DateTime.now();

    for (var session in sessions) {
      final hours = session['hours'] ?? 0.0;
      total += hours;

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
      final userData = await FirestoreHelper.getUserProfile(user.uid);
      if (userData == null) return;

      if (mounted) {
        setState(() {
          ID = userData['ID'] ?? "";
          studentName = userData['name'] ?? "";
          studentEmail = userData['email'] ?? user.email ?? "";
          studentDepartment = userData['department'] ?? "";
        });
      }
    } catch (e) {
      print('❌ Error loading student data: $e');
    }
  }

  void handleClockIn() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        title: const Text("Start Work Session"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Are you ready to start your work session?"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF02AEEE).withOpacity(0.1),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: const Color(0xFF02AEEE)),
                  const SizedBox(width: 8),
                  Text(
                    "Start time: ${DateFormat('hh:mm:ss a').format(DateTime.now())}",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                isSessionActive = true;
                startTime = DateTime.now();
                clockInTime = DateTime.now();
                clockOutTime = null;
                currentSessionDuration = "00:00:00";
              });
              timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
                if (mounted) {
                  setState(() {
                    final duration = DateTime.now().difference(startTime);
                    currentSessionDuration = _formatDuration(duration);
                  });
                }
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Session started at ${DateFormat('hh:mm:ss a').format(clockInTime!)}",
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF032540),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF032540),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            child: const Text("Start Session", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void handleClockOut() {
    timer?.cancel();
    
    setState(() {
      isSessionActive = false;
      clockOutTime = DateTime.now();
    });

    final duration = clockOutTime!.difference(startTime);
    final hoursWorked = (duration.inSeconds / 3600).toStringAsFixed(2);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        title: const Text("Session Completed"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF02AEEE).withOpacity(0.1),
                borderRadius: const BorderRadius.all(Radius.circular(15)),
              ),
              child: Column(
                children: [
                  _buildTimeRow("Clock In:", DateFormat('hh:mm:ss a').format(clockInTime!)),
                  const Divider(height: 16),
                  _buildTimeRow("Clock Out:", DateFormat('hh:mm:ss a').format(clockOutTime!)),
                  const Divider(height: 16),
                  _buildTimeRow("Duration:", _formatDuration(duration)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Text(
                      "$hoursWorked hours worked",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Don't forget to add a description before submitting!",
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text("Session ended. Add description and submit.")),
          ],
        ),
        backgroundColor: Color(0xFF032540),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildTimeRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontFamily: 'monospace')),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

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

  Future<void> handleSubmitHours() async {
    if (comment.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text("Please describe your work before submitting.")),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        title: const Text("Submit Work Hours"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Please review your session details:"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Column(
                children: [
                  if (clockInTime != null)
                    _buildDetailRow("Clock In:", DateFormat('hh:mm:ss a').format(clockInTime!)),
                  if (clockOutTime != null)
                    _buildDetailRow("Clock Out:", DateFormat('hh:mm:ss a').format(clockOutTime!)),
                  _buildDetailRow("Duration:", currentSessionDuration),
                  _buildDetailRow("Hours:", "${_calculateCurrentHours()} hrs"),
                  const Divider(),
                  _buildDetailRow("Description:", comment, isDescription: true),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF032540),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            child: const Text("Submit", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userData = await FirestoreHelper.getUserProfile(user.uid);
      if (userData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error: User profile not found."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final studentDepartment = userData['department'];
      final studentName = userData['name'] ?? "";
      final currentStudentEmail =
          studentEmail.isNotEmpty ? studentEmail : user.email ?? "";

      final parts = currentSessionDuration.split(':');
      double hours = 0.0;
      if (parts.length == 3) {
        final totalSeconds = (int.parse(parts[0]) * 3600) +
            (int.parse(parts[1]) * 60) +
            int.parse(parts[2]);
        hours = double.parse((totalSeconds / 3600).toStringAsFixed(2));
      }

      await FirestoreHelper.addWorkSession({
        'studentId': user.uid,
        'studentName': studentName,
        'studentEmail': currentStudentEmail,
        'department': studentDepartment,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'clockIn': clockInTime != null ? Timestamp.fromDate(clockInTime!) : null,
        'clockOut': clockOutTime != null ? Timestamp.fromDate(clockOutTime!) : null,
        'hours': hours,
        'reportDetails': comment.trim(),
        'status': 'Pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        comment = "";
        _draftDescription = "";
        isSessionActive = false;
        clockInTime = null;
        clockOutTime = null;
        currentSessionDuration = "00:00:00";
      });

      timer?.cancel();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text("$hours hours submitted for supervisor approval.")),
            ],
          ),
          backgroundColor: const Color(0xFF032540),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text("Error submitting hours: $e")),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isDescription = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: isDescription ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: isDescription 
                  ? const TextStyle(fontStyle: FontStyle.italic)
                  : const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> exportExcel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final sessions = await FirestoreHelper.getAllWorkSessions(user.uid);

      final workbook = excel.Excel.createExcel();
      final sheet = workbook['WorkStudy Report'];

      // Title and header styling
      sheet.appendRow([excel.TextCellValue("")]);
      sheet.appendRow([excel.TextCellValue("WORKSTUDY")]);
      sheet.appendRow([excel.TextCellValue("Student Work Report")]);
      sheet.appendRow([excel.TextCellValue("Generated by: $studentName ($studentEmail)")]);
      sheet.appendRow([excel.TextCellValue("Department: $studentDepartment")]);
      sheet.appendRow([
        excel.TextCellValue(
            "Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}")
      ]);
      sheet.appendRow([]);

      // Headers
      sheet.appendRow([
        excel.TextCellValue("Date"),
        excel.TextCellValue("Clock In"),
        excel.TextCellValue("Clock Out"),
        excel.TextCellValue("Hours"),
        excel.TextCellValue("Status"),
        excel.TextCellValue("Description"),
      ]);

      // Data rows - FIXED: Now properly displays clock in/out times
      for (var session in sessions) {
        final clockIn = session["clockIn"] as Timestamp?;
        final clockOut = session["clockOut"] as Timestamp?;
        
        // Format clock in time with full timestamp if available
        String clockInStr = 'N/A';
        if (clockIn != null) {
          final clockInDate = clockIn.toDate();
          clockInStr = DateFormat('hh:mm:ss a').format(clockInDate);
        }
        
        // Format clock out time with full timestamp if available
        String clockOutStr = 'N/A';
        if (clockOut != null) {
          final clockOutDate = clockOut.toDate();
          clockOutStr = DateFormat('hh:mm:ss a').format(clockOutDate);
        }
        
        sheet.appendRow([
          excel.TextCellValue(session["date"] ?? ''),
          excel.TextCellValue(clockInStr),
          excel.TextCellValue(clockOutStr),
          excel.TextCellValue(session["hours"]?.toStringAsFixed(2) ?? '0.00'),
          excel.TextCellValue(session["status"] ?? ''),
          excel.TextCellValue(session["reportDetails"] ?? ''),
        ]);
      }

      sheet.appendRow([]);
      sheet.appendRow([
        excel.TextCellValue("TOTAL HOURS:"),
        excel.TextCellValue(""),
        excel.TextCellValue(""),
        excel.TextCellValue(totalHoursWorked.toStringAsFixed(2)),
        excel.TextCellValue(""),
        excel.TextCellValue(""),
      ]);

      sheet.appendRow([]);
      sheet.appendRow([excel.TextCellValue("SUMMARY STATISTICS")]);
      sheet.appendRow([excel.TextCellValue("Total Sessions:"), excel.TextCellValue(sessions.length.toString())]);
      sheet.appendRow([excel.TextCellValue("Average Hours per Session:"), excel.TextCellValue(
        sessions.isEmpty ? "0.00" : (totalHoursWorked / sessions.length).toStringAsFixed(2)
      )]);
      sheet.appendRow([excel.TextCellValue("This Week Hours:"), excel.TextCellValue(thisWeekHours.toStringAsFixed(2))]);

      final bytes = workbook.encode();
      if (bytes == null) return;

      final fileName =
          "workstudy_${studentName.replaceAll(' ', '_')}_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx";
      String message;

      if (kIsWeb) {
        saveFileWeb(Uint8List.fromList(bytes), fileName);
        message = "✅ Excel file download initiated.";
      } else {
        final path = await saveFileOther(Uint8List.fromList(bytes), fileName);
        message = "✅ Excel exported to: $path";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: const Color(0xFF032540),
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text("Error exporting Excel: $e")),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> exportPDF() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final sessions = await FirestoreHelper.getAllWorkSessions(user.uid);

      // Load fonts that support Unicode
      final font = await PdfGoogleFonts.nunitoRegular();
      final boldFont = await PdfGoogleFonts.nunitoBold();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            // Prepare table data with proper clock times
            final List<List<String>> tableData = [];
            
            for (var session in sessions) {
              final clockIn = session["clockIn"] as Timestamp?;
              final clockOut = session["clockOut"] as Timestamp?;
              
              String clockInStr = 'N/A';
              if (clockIn != null) {
                final clockInDate = clockIn.toDate();
                clockInStr = DateFormat('hh:mm:ss a').format(clockInDate);
              }
              
              String clockOutStr = 'N/A';
              if (clockOut != null) {
                final clockOutDate = clockOut.toDate();
                clockOutStr = DateFormat('hh:mm:ss a').format(clockOutDate);
              }
              
              tableData.add([
                session["date"] ?? '',
                clockInStr,
                clockOutStr,
                session["hours"]?.toStringAsFixed(2) ?? '0.00',
                session["status"] ?? '',
                session["reportDetails"] ?? '',
              ]);
            }
            
            return [
              pw.Row(
                children: [
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
                          font: boldFont,
                          color: PdfColors.white,
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
                          font: boldFont,
                          fontSize: 18,
                          color: PdfColors.blue700,
                        ),
                      ),
                      pw.Text(
                        "Student Work Report",
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
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
                      "Student: $studentName",
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 11,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Email: $studentEmail",
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      "Department: $studentDepartment",
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      "Report Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}",
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "Work Sessions Detail",
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 14,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                ),
                cellStyle: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.grey800,
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                  5: pw.Alignment.centerLeft,
                },
                headers: ["Date", "Clock In", "Clock Out", "Hours", "Status", "Description"],
                data: tableData,
              ),
              pw.SizedBox(height: 15),
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
                          "Total Hours:",
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 11,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.Text(
                          totalHoursWorked.toStringAsFixed(2),
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 11,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "This Week:",
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          thisWeekHours.toStringAsFixed(2),
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "Total Sessions:",
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          sessions.length.toString(),
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName =
          "workstudy_${studentName.replaceAll(' ', '_')}_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf";
      String message;

      if (kIsWeb) {
        saveFileWeb(bytes, fileName);
        message = "✅ PDF file download initiated.";
      } else {
        final path = await saveFileOther(bytes, fileName);
        message = "✅ PDF exported to: $path";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: const Color(0xFF032540),
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text("Error exporting PDF: $e")),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Hello ${studentName.isNotEmpty ? studentName : ID} 👋",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSessionActive ? Icons.circle : Icons.circle_outlined,
                                      color: isSessionActive ? Colors.green : Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isSessionActive ? "Active" : "Inactive",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow(Icons.business, "Department", studentDepartment),
                                const SizedBox(height: 4),
                                _buildInfoRow(Icons.email, "Email", studentEmail),
                                if (isSessionActive && clockInTime != null) ...[
                                  const SizedBox(height: 4),
                                  _buildInfoRow(
                                    Icons.access_time,
                                    "Clocked in at",
                                    DateFormat('hh:mm:ss a').format(clockInTime!),
                                    iconColor: Colors.green,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildInfoRow(IconData icon, String label, String value, {Color iconColor = Colors.white70}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? "Loading..." : value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
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
            if (isSessionActive && clockInTime != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Clocked in at",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          DateFormat('hh:mm:ss a').format(clockInTime!),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: const BorderRadius.all(Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            "Active",
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
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
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: "monospace",
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${_calculateCurrentHours()} hours",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isSessionActive ? null : handleClockIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 17),
                    ),
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text(
                      "Clock In",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isSessionActive ? handleClockOut : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSessionActive ? Colors.red : Colors.grey,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 17),
                    ),
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: const Text(
                      "Clock Out",
                      style: TextStyle(color: Colors.white, fontSize: 16),
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

  Widget _buildCommentCard(Color primaryColor, Color accentColor) {
    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.description, color: accentColor),
                const SizedBox(width: 8),
                const Text(
                  "Work Description",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
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
              onChanged: (val) {
                setState(() => comment = val);
                _draftSaveTimer?.cancel();
                _draftSaveTimer = Timer(const Duration(seconds: 2), _saveDraftDescription);
              },
              decoration: InputDecoration(
                hintText: "Describe your work...",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: comment.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            comment = "";
                            _draftDescription = "";
                          });
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: handleSubmitHours,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
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
    List<Map<String, dynamic>> filteredActivities = studentActivities
        .where((activity) =>
            activity["status"]?.toLowerCase() == selectedActivityTab.toLowerCase())
        .toList();

    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
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
              height: 250,
              child: filteredActivities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "No $selectedActivityTab activities",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredActivities.length,
                      itemBuilder: (context, index) {
                        final activity = filteredActivities[index];
                        final clockIn = activity["clockIn"] as DateTime?;
                        final clockOut = activity["clockOut"] as DateTime?;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          activity["date"],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: activity["status"]?.toLowerCase() == "approved"
                                          ? Colors.green
                                          : activity["status"]?.toLowerCase() == "declined"
                                              ? Colors.red
                                              : Colors.orange,
                                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                                    ),
                                    child: Text(
                                      activity["status"] ?? 'Pending',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (clockIn != null || clockOut != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                                  ),
                                  child: Row(
                                    children: [
                                      if (clockIn != null)
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.login,
                                                size: 12,
                                                color: Colors.green.shade700,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                DateFormat('hh:mm a').format(clockIn),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (clockOut != null)
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.logout,
                                                size: 12,
                                                color: Colors.red.shade700,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                DateFormat('hh:mm a').format(clockOut),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.red.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text(
                                activity["description"] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF032540),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (activity["feedback"] != null && activity["feedback"].toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.feedback,
                                        size: 12,
                                        color: Colors.blue.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          activity["feedback"],
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "${activity["hours"]?.toStringAsFixed(1)}h",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF032540),
                                  ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.download, color: accentColor),
                const SizedBox(width: 8),
                const Text(
                  "Export Reports",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Download your work history with detailed timestamps",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildExportButton(
                    icon: Icons.table_chart,
                    label: "Excel",
                    color: Colors.green,
                    onPressed: exportExcel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildExportButton(
                    icon: Icons.picture_as_pdf,
                    label: "PDF",
                    color: Colors.red,
                    onPressed: exportPDF,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      label: Text(
        label,
        style: TextStyle(color: color),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}