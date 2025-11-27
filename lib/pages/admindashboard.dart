import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workstudy/pages/login.dart';
import 'package:workstudy/service/firebase_service.dart';
import 'package:workstudy/export_helper/save_file_other.dart';
import 'package:workstudy/export_helper/save_file_web.dart'
    if (dart.library.io) 'package:workstudy/export_helper/save_file_other.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic> stats = {
    "totalStudents": 0,
    "totalSupervisors": 0,
    "pendingApprovals": 0,
    "totalHoursApproved": 0,
  };

  Map<String, dynamic> reportStats = {
    "thisMonthHours": 0,
    "lastMonthHours": 0,
    "avgHoursPerStudent": 0,
  };

  String searchQuery = "";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _fadeAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(_animationController);

    // Load initial data
    _loadDashboardStats();
    _loadReportStats();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // --- TIMESTAMP UTILITY FUNCTIONS ---

  /// Converts any timestamp format to DateTime
  DateTime? parseAnyTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is int) {
        // Handle milliseconds timestamp
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        return DateTime.tryParse(timestamp);
      } else if (timestamp is DateTime) {
        return timestamp;
      }
    } catch (e) {
      print('Error parsing timestamp: $e');
    }
    return null;
  }

  /// Formats timestamp to readable format: "Monday, November 18, 2024 4:35:48 PM"
  String formatTimestamp(dynamic timestamp) {
    final dateTime = parseAnyTimestamp(timestamp);
    if (dateTime == null) return 'Date not available';

    return DateFormat('EEEE, MMMM d, yyyy h:mm:ss a').format(dateTime);
  }

  /// Formats timestamp for export files
  String formatTimestampForExport(dynamic timestamp) {
    final dateTime = parseAnyTimestamp(timestamp);
    if (dateTime == null) return 'N/A';

    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  // Load dashboard statistics
  Future<void> _loadDashboardStats() async {
    try {
      final dashboardStats = await _firebaseService.getDashboardStats();
      setState(() {
        stats = dashboardStats;
      });
    } catch (e) {
      _showSnack("Error loading dashboard stats: $e");
    }
  }

  // Load report statistics
  Future<void> _loadReportStats() async {
    try {
      final now = DateTime.now();
      final firstDayThisMonth = DateTime(now.year, now.month, 1);
      final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
      final lastDayLastMonth = DateTime(now.year, now.month, 0);

      // Fetch work sessions for this month
      final thisMonthSessions = await _firestore
          .collection('work_sessions')
          .where('date',
              isGreaterThanOrEqualTo:
                  DateFormat('yyyy-MM-dd').format(firstDayThisMonth))
          .where('status', isEqualTo: 'approved')
          .get();

      // Fetch work sessions for last month
      final lastMonthSessions = await _firestore
          .collection('work_sessions')
          .where('date',
              isGreaterThanOrEqualTo:
                  DateFormat('yyyy-MM-dd').format(firstDayLastMonth))
          .where('date',
              isLessThanOrEqualTo:
                  DateFormat('yyyy-MM-dd').format(lastDayLastMonth))
          .where('status', isEqualTo: 'approved')
          .get();

      // Calculate total hours
      double thisMonthHours = 0;
      double lastMonthHours = 0;

      for (var session in thisMonthSessions.docs) {
        final data = session.data();
        thisMonthHours += (data['hours'] ?? 0.0).toDouble();
      }

      for (var session in lastMonthSessions.docs) {
        final data = session.data();
        lastMonthHours += (data['hours'] ?? 0.0).toDouble();
      }

      // Calculate average hours per student
      final students = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Student')
          .get();
      final totalStudents = students.docs.length;
      final avgHours = totalStudents > 0 ? (thisMonthHours / totalStudents) : 0;

      setState(() {
        reportStats = {
          "thisMonthHours": thisMonthHours,
          "lastMonthHours": lastMonthHours,
          "avgHoursPerStudent": avgHours,
        };
      });
    } catch (e) {
      _showSnack("Error loading report stats: $e");
    }
  }

  Future<void> _showLoadingEffect(Future<void> Function() action) async {
    setState(() => isLoading = true);
    try {
      await action();
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return regex.hasMatch(email);
  }

  void _showSnack(String message, {Color color = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Center(
          child: Text(message, style: const TextStyle(color: Colors.white)),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 40, left: 40, right: 40),
      ),
    );
  }

  // --- Export Functions ---

  Future<List<Map<String, dynamic>>> _fetchReportData() async {
    try {
      // Fetch users data - order by createdAt descending (newest first)
      final usersSnapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();
      final users = usersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'role': data['role'] ?? '',
          'status': data['status'] ?? '',
          'department': data['department'] ?? '',
          'createdAt': formatTimestampForExport(data['createdAt']),
        };
      }).toList();

      // Fetch work sessions data
      final sessionsSnapshot = await _firestore
          .collection('work_sessions')
          .orderBy('submittedAt', descending: true)
          .get();
      final sessions = sessionsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'studentId': data['studentId'] ?? '',
          'studentName': data['studentName'] ?? '',
          'studentEmail': data['studentEmail'] ?? '',
          'hours': data['hours'] ?? 0.0,
          'status': data['status'] ?? '',
          'reportDetails': data['reportDetails'] ?? '',
          'date': data['date'] ?? '',
          'department': data['department'] ?? '',
          'submittedAt': formatTimestampForExport(data['submittedAt']),
        };
      }).toList();

      return [
        {'type': 'users', 'data': users},
        {'type': 'work_sessions', 'data': sessions},
      ];
    } catch (e) {
      throw Exception('Failed to fetch report data: $e');
    }
  }

  Future<void> _exportExcel(String format) async {
    await _showLoadingEffect(() async {
      try {
        final reportData = await _fetchReportData();
        final workbook = excel.Excel.createExcel();

        // Create sheets for different data types
        for (var section in reportData) {
          final sheet = workbook[section['type']];
          final data = section['data'] as List<Map<String, dynamic>>;

          if (data.isEmpty) continue;

          // Create headers from first item's keys
          final headers = data.first.keys.toList();
          sheet.appendRow(headers.map((h) => excel.TextCellValue(h)).toList());

          // Add data rows
          for (var row in data) {
            final rowData = headers.map((header) {
              final value = row[header];
              return excel.TextCellValue(value?.toString() ?? '');
            }).toList();
            sheet.appendRow(rowData);
          }
        }

        final bytes = workbook.encode();
        if (bytes == null) {
          _showSnack("Failed to generate Excel file");
          return;
        }

        final fileName =
            "workstudy_admin_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx";

        if (kIsWeb) {
          saveFileWeb(Uint8List.fromList(bytes), fileName);
          _showSnack(
            "✅ Excel report download initiated!",
            color: Colors.green,
          );
        } else {
          final path = await saveFileOther(Uint8List.fromList(bytes), fileName);
          _showSnack(
            "✅ Excel report exported to: $path",
            color: Colors.green,
          );
        }
      } catch (e) {
        _showSnack("Excel export failed: $e");
      }
    });
  }

  Future<void> _exportPDF(String format) async {
    await _showLoadingEffect(() async {
      try {
        final reportData = await _fetchReportData();
        final pdf = pw.Document();

        for (var section in reportData) {
          final data = section['data'] as List<Map<String, dynamic>>;
          if (data.isEmpty) continue;

          final headers = data.first.keys.toList();
          final tableData = data.map((row) {
            return headers
                .map((header) => row[header]?.toString() ?? '')
                .toList();
          }).toList();

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
                              "Admin ${section['type']} Report",
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
                            "Generated on: ${formatTimestampForExport(DateTime.now())}",
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            "Total Records: ${data.length}",
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 20),

                    // Table
                    pw.Text(
                      "${section['type'].replaceAll('_', ' ').toUpperCase()}",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    // Data Table
                    // ignore: deprecated_member_use
                    pw.Table.fromTextArray(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        fontSize: 8,
                      ),
                      headerDecoration: pw.BoxDecoration(
                        color: PdfColors.blue700,
                      ),
                      cellStyle: pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey800,
                      ),
                      headers: headers,
                      data: tableData,
                    ),
                  ],
                );
              },
            ),
          );
        }

        final bytes = await pdf.save();
        final fileName =
            "workstudy_admin_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf";

        if (kIsWeb) {
          saveFileWeb(bytes, fileName);
          _showSnack(
            "✅ PDF report download initiated!",
            color: Colors.green,
          );
        } else {
          final path = await saveFileOther(bytes, fileName);
          _showSnack(
            "✅ PDF report exported to: $path",
            color: Colors.green,
          );
        }
      } catch (e) {
        _showSnack("PDF export failed: $e");
      }
    });
  }

  // --- User Management Functions ---

  Future<void> _createUserWithEmailAndPassword(String email, String password,
      String name, String role, String department, String idNumber) async {
    try {
      // Use a different approach - create user through a separate auth instance
      // This prevents auto-signin
      final FirebaseAuth tempAuth =
          FirebaseAuth.instanceFor(app: Firebase.app());

      // Create user without affecting current session
      final UserCredential userCredential =
          await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store user data in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'role': role,
        'department': department,
        'idNumber': idNumber,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign out from the temp auth instance (doesn't affect main auth)
      await tempAuth.signOut();

      // Success! Admin stays logged in
      return;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  void _confirmDelete(String userId, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User"),
        content: Text("Are you sure you want to remove $email?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _showLoadingEffect(() async {
                try {
                  await _firebaseService.deleteUser(userId);
                  _showSnack(
                    "$email removed successfully.",
                    color: Colors.green,
                  );
                  _loadDashboardStats();
                } catch (e) {
                  _showSnack("Error deleting user: $e");
                }
              });
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _addUserDialog(String role) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final idNumberController = TextEditingController();
    final passwordController = TextEditingController();
    final departmentController = TextEditingController();

    bool obscureTextAddUser = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Add $role"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: idNumberController,
                    decoration: const InputDecoration(
                      labelText: "ID Number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: departmentController,
                    decoration: const InputDecoration(
                      labelText: "Department",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscureTextAddUser,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: const OutlineInputBorder(),
                      hintText: "Minimum 6 characters",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureTextAddUser
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureTextAddUser = !obscureTextAddUser;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  final name = nameController.text.trim();
                  final idNumber = idNumberController.text.trim();
                  final department = departmentController.text.trim();
                  final password = passwordController.text.trim();

                  if (!_isValidEmail(email) ||
                      name.isEmpty ||
                      idNumber.isEmpty ||
                      department.isEmpty ||
                      password.length < 6) {
                    Navigator.pop(context);
                    _showSnack(
                        "⚠️ Please fill all fields correctly. Password must be at least 6 characters.");
                    return;
                  }

                  Navigator.pop(context);
                  await _showLoadingEffect(() async {
                    try {
                      await _createUserWithEmailAndPassword(
                          email, password, name, role, department, idNumber);
                      _showSnack(
                        "$role added successfully. They can now login with the provided credentials.",
                        color: Colors.green,
                      );
                      _loadDashboardStats();
                    } catch (e) {
                      _showSnack("Error adding user: $e");
                    }
                  });
                },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editUserDialog(Map<String, dynamic> user, String userId) {
    final emailController = TextEditingController(text: user["email"] ?? '');
    final nameController = TextEditingController(text: user["name"] ?? '');
    final idNumberController =
        TextEditingController(text: user["idNumber"] ?? '');
    final departmentController =
        TextEditingController(text: user["department"] ?? '');
    String role = user["role"] ?? 'Student';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit User"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idNumberController,
                decoration: const InputDecoration(
                  labelText: "ID Number",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: "Department",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                items: ["Student", "Supervisor"]
                    .map(
                      (r) => DropdownMenuItem(value: r, child: Text(r)),
                    )
                    .toList(),
                onChanged: (val) => role = val!,
                decoration: const InputDecoration(
                  labelText: "Role",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final name = nameController.text.trim();
              final idNumber = idNumberController.text.trim();
              final department = departmentController.text.trim();

              if (!_isValidEmail(email) ||
                  name.isEmpty ||
                  idNumber.isEmpty ||
                  department.isEmpty) {
                Navigator.pop(context);
                _showSnack("⚠️ Please fill all fields correctly.");
                return;
              }

              Navigator.pop(context);
              await _showLoadingEffect(() async {
                try {
                  await _firebaseService.updateUser(
                      userId, email, role, name, department, idNumber);
                  _showSnack(
                    "✅ User updated successfully.",
                    color: Colors.greenAccent,
                  );
                  _loadDashboardStats();
                } catch (e) {
                  _showSnack("Error updating user: $e");
                }
              });
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Search Users"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter email, name or role",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => searchQuery = controller.text.toLowerCase());
            },
            child: const Text("Search"),
          ),
        ],
      ),
    );
  }

  void _approveUser(String userId, String email) async {
    await _showLoadingEffect(() async {
      try {
        await _firebaseService.updateUserStatus(userId, 'approved');
        _showSnack(
          "$email approved successfully.",
          color: Colors.green,
        );
        _loadDashboardStats();
      } catch (e) {
        _showSnack("Error approving user: $e");
      }
    });
  }

  void _declineUser(String userId, String email) async {
    await _showLoadingEffect(() async {
      try {
        await _firebaseService.updateUserStatus(userId, 'declined');
        _showSnack(
          "$email declined.",
          color: Colors.red,
        );
        _loadDashboardStats();
      } catch (e) {
        _showSnack("Error declining user: $e");
      }
    });
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF02AEEE), Color(0xFF02AEEE)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: const Text(
                            "WorkStudy",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white),
                            onPressed: () {
                              _firebaseService.signOut();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tabs
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.black54,
                      indicatorColor: Colors.blueAccent,
                      tabs: const [
                        Tab(icon: Icon(Icons.dashboard), text: "Overview"),
                        Tab(icon: Icon(Icons.group), text: "Users"),
                        Tab(icon: Icon(Icons.bar_chart), text: "Reports"),
                      ],
                    ),
                  ),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildUsersTab(),
                        _buildReportsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (isLoading)
            Container(
              color: Colors.black54.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Overview Tab ---
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "System Overview 🔧",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text("Manage users, monitor progress, and generate reports."),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _statCard(
                Icons.people,
                "Students",
                stats["totalStudents"].toString(),
                Colors.blue,
              ),
              _statCard(
                Icons.supervisor_account,
                "Supervisors",
                stats["totalSupervisors"].toString(),
                Colors.purple,
              ),
              _statCard(
                Icons.pending_actions,
                "Pending Approvals",
                stats["pendingApprovals"].toString(),
                Colors.orange,
              ),
              _statCard(
                Icons.check_circle,
                "Hours Approved",
                stats["totalHoursApproved"].toString(),
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Users Tab ---
  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.search,
                  label: "Search",
                  color: Colors.black87,
                  textColor: Colors.white,
                  iconColor: Colors.white,
                  onPressed: _showSearchDialog,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.person_add_alt_1,
                  label: "Add Student",
                  color: Colors.white,
                  textColor: Colors.blue,
                  iconColor: Colors.blue,
                  onPressed: () => _addUserDialog("Student"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.person_add,
                  label: "Add Supervisor",
                  color: Colors.white,
                  textColor: Colors.blue,
                  iconColor: Colors.blue,
                  onPressed: () => _addUserDialog("Supervisor"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firebaseService.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs;
                // Sort users by createdAt timestamp (newest first)
                final sortedUsers = users
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = parseAnyTimestamp(aData['createdAt']);
                    final bTime = parseAnyTimestamp(bData['createdAt']);

                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;

                    return bTime
                        .compareTo(aTime); // Descending order (newest first)
                  });

                final filteredUsers = sortedUsers.where((user) {
                  final userData = user.data() as Map<String, dynamic>;
                  final email =
                      userData['email']?.toString().toLowerCase() ?? '';
                  final role = userData['role']?.toString().toLowerCase() ?? '';
                  final name = userData['name']?.toString().toLowerCase() ?? '';
                  final idNumber =
                      userData['idNumber']?.toString().toLowerCase() ?? '';

                  return email.contains(searchQuery) ||
                      role.contains(searchQuery) ||
                      name.contains(searchQuery) ||
                      idNumber.contains(searchQuery);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (_, i) {
                    final user = filteredUsers[i];
                    final userData = user.data() as Map<String, dynamic>;
                    final userId = user.id;
                    final email = userData['email'] ?? 'No email';
                    final role = userData['role'] ?? 'No role';
                    final status = userData['status'] ?? 'pending';
                    final name = userData['name'] ?? 'No name';
                    final idNumber = userData['idNumber'] ?? 'No ID';
                    final department =
                        userData['department'] ?? 'No department';
                    final createdAt = userData['createdAt'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(email),
                            const SizedBox(height: 4),
                            Text('ID: $idNumber • Department: $department'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('$role • '),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: status == 'approved'
                                        ? Colors.green
                                        : status == 'pending'
                                            ? Colors.orange
                                            : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Joined: ${formatTimestamp(createdAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _actionIcon(
                                  icon: Icons.check_circle,
                                  label: "Approve",
                                  color: status == 'approved'
                                      ? Colors.grey
                                      : Colors.green,
                                  onPressed: status == 'approved'
                                      ? null
                                      : () => _approveUser(userId, email),
                                ),
                                _actionIcon(
                                  icon: Icons.cancel,
                                  label: "Decline",
                                  color: status == 'declined'
                                      ? Colors.grey
                                      : Colors.red,
                                  onPressed: status == 'declined'
                                      ? null
                                      : () => _declineUser(userId, email),
                                ),
                                _actionIcon(
                                  icon: Icons.edit,
                                  label: "Edit",
                                  color: Colors.blue,
                                  onPressed: () =>
                                      _editUserDialog(userData, userId),
                                ),
                                _actionIcon(
                                  icon: Icons.delete,
                                  label: "Delete",
                                  color: Colors.orange,
                                  onPressed: () =>
                                      _confirmDelete(userId, email),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Reports Tab ---
  Widget _buildReportsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [_exportCard(), const SizedBox(height: 16), _reportSummary()],
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _statCard(IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 45,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ElevatedButton.icon(
          icon: Icon(icon, size: 18, color: iconColor),
          label: Text(label, style: TextStyle(fontSize: 14, color: textColor)),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: color),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _exportCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Export Reports",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _exportPDF("PDF"),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Export PDF Report"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _exportExcel("Excel"),
              icon: const Icon(Icons.table_chart),
              label: const Text("Export Excel Report"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportSummary() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Report Summary",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            _summaryRow("This Month",
                "${reportStats["thisMonthHours"].toStringAsFixed(1)} hours"),
            _summaryRow("Last Month",
                "${reportStats["lastMonthHours"].toStringAsFixed(1)} hours"),
            _summaryRow("Total Students", stats["totalStudents"].toString()),
            _summaryRow("Avg Hours/Student",
                "${reportStats["avgHoursPerStudent"].toStringAsFixed(1)} hrs"),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
