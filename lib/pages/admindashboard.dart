import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
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
    "totalHoursApproved": 0.0,
    "totalUsers": 0,
  };

  Map<String, dynamic> reportStats = {
    "thisMonthHours": 0.0,
    "lastMonthHours": 0.0,
    "avgHoursPerStudent": 0.0,
  };

  String searchQuery = "";
  bool isLoading = false;
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;

  // State variables for clickable cards
  List<String> _studentsEmails = [];
  List<String> _supervisorsEmails = [];
  List<Map<String, dynamic>> _pendingActivities = [];
  List<Map<String, dynamic>> _approvedActivities = [];

  // ========== NEW SIMPLIFIED FILTER VARIABLES ==========
  String _selectedUserType = 'All'; // 'All', 'Students', 'Supervisors'
  String _departmentFilter = 'All';
  List<String> _availableDepartments = [];

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

    // Load all data at once
    _loadAllData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // --- MAIN DATA LOADING METHOD ---
  Future<void> _loadAllData() async {
    if (_isRefreshing) return;

    setState(() {
      isLoading = true;
      _isRefreshing = true;
    });

    try {
      await Future.wait([
        _loadDashboardStats(),
        _loadReportStats(),
        _loadEmailLists(),
        _loadDepartments(),
      ]);
      _lastRefreshTime = DateTime.now();
    } catch (e) {
      _showSnack("Error loading dashboard data: $e");
    } finally {
      setState(() {
        isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  // ========== LOAD UNIQUE DEPARTMENTS FOR FILTER ==========
  Future<void> _loadDepartments() async {
    try {
      final users = await _firestore.collection('users').get();
      Set<String> departments = {};
      
      for (var doc in users.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dept = data['department']?.toString();
        if (dept != null && dept.isNotEmpty) {
          departments.add(dept);
        }
      }
      
      setState(() {
        _availableDepartments = departments.toList()..sort();
      });
    } catch (e) {
      print('Error loading departments: $e');
    }
  }

  // Helper method to extract hours
  double _extractHours(Map<String, dynamic> data) {
    List<String> possibleFields = ['hours', 'hour', 'totalHours', 'approvedHours', 'workHours', 'duration'];
    
    for (var field in possibleFields) {
      if (data.containsKey(field)) {
        final value = data[field];
        if (value != null) {
          if (value is int) return value.toDouble();
          if (value is double) return value;
          if (value is String) {
            final parsed = double.tryParse(value);
            if (parsed != null) return parsed;
          }
          if (value is num) return value.toDouble();
        }
      }
    }
    return 0.0;
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    await _loadAllData();
    _showSnack("Dashboard data refreshed!", color: Colors.green);
  }

  DateTime? parseAnyTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    try {
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (timestamp is String) return DateTime.tryParse(timestamp);
      if (timestamp is DateTime) return timestamp;
    } catch (e) {
      print('Error parsing timestamp: $e');
    }
    return null;
  }

  String formatTimestamp(dynamic timestamp) {
    final dateTime = parseAnyTimestamp(timestamp);
    if (dateTime == null) return 'Date not available';
    return DateFormat('EEEE, MMMM d, yyyy h:mm:ss a').format(dateTime);
  }

  String formatTimestampForExport(dynamic timestamp) {
    final dateTime = parseAnyTimestamp(timestamp);
    if (dateTime == null) return 'N/A';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  // ============================================================
  // Load dashboard statistics - Counts ALL case variations
  // ============================================================
  Future<void> _loadDashboardStats() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      final allUsers = await _firestore.collection('users').get();

      int totalStudents = 0;
      int totalSupervisors = 0;
      int pendingApprovals = 0;
      int otherUsers = 0;

      for (var doc in allUsers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final originalRole = data['role']?.toString() ?? '';
        final role = originalRole.toLowerCase();
        final status = data['status']?.toString()?.toLowerCase() ?? '';

        if (role == 'student') {
          totalStudents++;
          if (status == 'pending') pendingApprovals++;
        } else if (role == 'supervisor') {
          totalSupervisors++;
          if (status == 'pending') pendingApprovals++;
        } else {
          otherUsers++;
          if (status == 'pending') pendingApprovals++;
        }
      }

      setState(() {
        stats = {
          "totalStudents": totalStudents,
          "totalSupervisors": totalSupervisors,
          "pendingApprovals": pendingApprovals,
          "totalHoursApproved": stats["totalHoursApproved"],
          "totalUsers": allUsers.docs.length,
        };
      });
      
      await _loadApprovedHours();
      
    } catch (e) {
      print('❌ Error loading dashboard stats: $e');
      _showSnack('Error loading stats: $e');
    }
  }

  Future<void> _loadApprovedHours() async {
    try {
      final allSessions = await _firestore.collection('work_sessions').get();
      
      double totalHoursApproved = 0.0;
      int approvedCount = 0;
      
      for (var session in allSessions.docs) {
        final data = session.data() as Map<String, dynamic>;
        final status = data['status']?.toString().toLowerCase() ?? '';
        
        if (status == 'approved') {
          approvedCount++;
          totalHoursApproved += _extractHours(data);
        }
      }
      
      setState(() {
        stats["totalHoursApproved"] = totalHoursApproved;
      });
      
    } catch (e) {
      print('❌ Error loading approved hours: $e');
    }
  }

  Future<void> _loadReportStats() async {
    try {
      final now = DateTime.now();
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);

      final allSessions = await _firestore.collection('work_sessions').get();

      double thisMonthHours = 0.0;
      double lastMonthHours = 0.0;
      int thisMonthCount = 0;
      int lastMonthCount = 0;

      for (var session in allSessions.docs) {
        final data = session.data() as Map<String, dynamic>;
        final status = data['status']?.toString().toLowerCase() ?? '';
        
        if (status == 'approved') {
          final submittedAt = parseAnyTimestamp(data['submittedAt']);
          final hours = _extractHours(data);

          if (submittedAt != null && hours > 0) {
            if (submittedAt.year == now.year && submittedAt.month == now.month) {
              thisMonthHours += hours;
              thisMonthCount++;
            } else if (submittedAt.year == lastMonthStart.year &&
                submittedAt.month == lastMonthStart.month) {
              lastMonthHours += hours;
              lastMonthCount++;
            }
          }
        }
      }

      final allStudents = await _firestore.collection('users').get();
      
      int totalActiveStudents = 0;
      for (var student in allStudents.docs) {
        final data = student.data() as Map<String, dynamic>;
        final role = data['role']?.toString().toLowerCase() ?? '';
        final status = data['status']?.toString().toLowerCase() ?? '';
        if (role == 'student' && status == 'approved') {
          totalActiveStudents++;
        }
      }

      final avgHours = totalActiveStudents > 0 ? (thisMonthHours / totalActiveStudents) : 0.0;

      setState(() {
        reportStats = {
          "thisMonthHours": thisMonthHours,
          "lastMonthHours": lastMonthHours,
          "avgHoursPerStudent": avgHours,
          "thisMonthCount": thisMonthCount,
          "lastMonthCount": lastMonthCount,
        };
      });
    } catch (e) {
      print('❌ Error loading report stats: $e');
    }
  }

  Future<void> _loadEmailLists() async {
    try {
      final allUsers = await _firestore.collection('users').get();
      
      _studentsEmails = [];
      _supervisorsEmails = [];
      
      for (var doc in allUsers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['role']?.toString().toLowerCase() ?? '';
        final email = data['email']?.toString().trim() ?? '';
        
        if (role == 'student' && email.isNotEmpty && _isValidEmail(email)) {
          _studentsEmails.add(email);
        } else if (role == 'supervisor' && email.isNotEmpty && _isValidEmail(email)) {
          _supervisorsEmails.add(email);
        }
      }

      _pendingActivities = [];
      for (var doc in allUsers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString().toLowerCase() ?? '';
        
        if (status == 'pending') {
          _pendingActivities.add({
            'email': data['email']?.toString().trim() ?? 'No email',
            'role': data['role']?.toString() ?? 'Unknown',
            'idNumber': data['idNumber']?.toString() ?? 'No ID',
            'department': data['department']?.toString() ?? 'No department',
            'status': data['status']?.toString() ?? 'pending',
            'createdAt': data['createdAt'],
          });
        }
      }

      final allSessions = await _firestore.collection('work_sessions').get();
      
      _approvedActivities = [];
      for (var doc in allSessions.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString().toLowerCase() ?? '';
        
        if (status == 'approved') {
          _approvedActivities.add({
            'studentEmail': data['studentEmail']?.toString().trim() ?? 'No email',
            'hours': _extractHours(data),
            'date': data['date']?.toString() ?? 'No date',
            'studentName': data['studentName']?.toString() ?? 'Unknown',
            'department': data['department']?.toString() ?? 'Unknown',
            'supervisorEmail': data['supervisorEmail']?.toString().trim() ?? 'No supervisor',
          });
        }
      }
      
    } catch (e) {
      print('❌ Error loading email lists: $e');
    }
  }

  // ========== ID VALIDATION FUNCTION ==========
  bool _isValidIdNumber(String idNumber) {
    if (idNumber.isEmpty) return false;
    // Check if it contains only digits and length is between 6 and 14
    final regex = RegExp(r'^\d{6,14}$');
    return regex.hasMatch(idNumber);
  }

  // ========== SIMPLIFIED EXPORT FILTER DIALOG ==========
  Future<void> _showExportFilterDialog() async {
    String tempUserType = _selectedUserType;
    String tempDepartment = _departmentFilter;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Export Filters'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('User Type', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tempUserType,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Users')),
                          DropdownMenuItem(value: 'Students', child: Text('Students Only')),
                          DropdownMenuItem(value: 'Supervisors', child: Text('Supervisors Only')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => tempUserType = value);
                          }
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  const Text('Department', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tempDepartment,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: 'All',
                            child: Text('All Departments'),
                          ),
                          ..._availableDepartments.map((dept) => DropdownMenuItem(
                            value: dept,
                            child: Text(dept),
                          )),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => tempDepartment = value);
                          }
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedUserType = tempUserType;
                    _departmentFilter = tempDepartment;
                  });
                  Navigator.pop(context);
                  _showExportOptions();
                },
                child: const Text('Apply Filters'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Export Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _getFilterDescription(),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _exportWithFilters('PDF'),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _exportWithFilters('Excel'),
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showExportFilterDialog();
              },
              child: const Text('Adjust Filters'),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterDescription() {
    List<String> filters = [];
    if (_selectedUserType != 'All') {
      filters.add(_selectedUserType);
    }
    if (_departmentFilter != 'All') {
      filters.add('Dept: $_departmentFilter');
    }
    return filters.isEmpty ? 'No filters applied' : filters.join(' • ');
  }

  // ========== SIMPLIFIED DATA FETCHING WITH NULL SAFETY ==========
  Future<Map<String, dynamic>> _fetchFilteredData() async {
    try {
      // Build users query with department filter if needed
      Query usersQuery = _firestore.collection('users');
      
      if (_departmentFilter != 'All') {
        usersQuery = usersQuery.where('department', isEqualTo: _departmentFilter);
      }
      
      final usersSnapshot = await usersQuery.get();
      
      // Filter by user type in code (since we can't have two where clauses without index)
      List<Map<String, dynamic>> users = [];
      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['role']?.toString().toLowerCase() ?? '';
        
        bool includeUser = true;
        if (_selectedUserType == 'Students') {
          includeUser = role == 'student';
        } else if (_selectedUserType == 'Supervisors') {
          includeUser = role == 'supervisor';
        }
        
        if (includeUser) {
          users.add({
            'id': doc.id,
            'email': data['email']?.toString() ?? '',
            'role': data['role']?.toString() ?? '',
            'status': data['status']?.toString() ?? '',
            'department': data['department']?.toString() ?? '',
            'idNumber': data['idNumber']?.toString() ?? '',
            'name': data['name']?.toString() ?? '',
            'createdAt': formatTimestampForExport(data['createdAt']),
          });
        }
      }

      // Build sessions query with department filter if needed
      Query sessionsQuery = _firestore.collection('work_sessions');
      
      if (_departmentFilter != 'All') {
        sessionsQuery = sessionsQuery.where('department', isEqualTo: _departmentFilter);
      }
      
      final sessionsSnapshot = await sessionsQuery.get();
      
      List<Map<String, dynamic>> sessions = [];
      for (var doc in sessionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        sessions.add({
          'id': doc.id,
          'studentId': data['studentId']?.toString() ?? '',
          'studentEmail': data['studentEmail']?.toString() ?? '',
          'hours': _extractHours(data),
          'status': data['status']?.toString() ?? '',
          'reportDetails': data['reportDetails']?.toString() ?? '',
          'date': data['date']?.toString() ?? '',
          'department': data['department']?.toString() ?? '',
          'submittedAt': formatTimestampForExport(data['submittedAt']),
        });
      }

      return {
        'users': users,
        'sessions': sessions,
        'totalUsers': users.length,
        'totalSessions': sessions.length,
        'totalHours': sessions.fold(0.0, (sum, s) => sum + (s['hours'] as double)),
      };
    } catch (e) {
      print('❌ Error fetching filtered data: $e');
      throw Exception('Failed to fetch report data: $e');
    }
  }

  Future<void> _exportWithFilters(String format) async {
    await _showLoadingEffect(() async {
      try {
        final data = await _fetchFilteredData();
        
        if (format == 'PDF') {
          await _generatePDF(data);
        } else {
          await _generateExcel(data);
        }
        
        _showSnack("✅ $format report generated with filters", color: Colors.green);
      } catch (e) {
        print('❌ Export error: $e');
        _showSnack("Export failed: $e");
      }
    });
  }

  // --- PDF Generation with Filters (REMOVED Student Name column) ---
  Future<void> _generatePDF(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    String formatNumber(dynamic value, {int decimals = 2}) {
      if (value == null) return '0.00';
      if (value is num) return value.toStringAsFixed(decimals);
      return value.toString();
    }

    // Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                width: 100,
                height: 100,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    'WS',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 40,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'WorkStudy Admin Report',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                _getFilterDescription(),
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated: ${DateFormat('EEEE, MMMM d, yyyy - h:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 40),
              pw.Container(
                width: 400,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfSummaryRow('Total Users', '${data['totalUsers']}'),
                    _buildPdfSummaryRow('Total Sessions', '${data['totalSessions']}'),
                    _buildPdfSummaryRow('Total Hours', '${formatNumber(data['totalHours'])} h'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Users Section
    final users = data['users'] as List;
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          if (users.isEmpty) {
            return pw.Center(
              child: pw.Text('No user data available.', style: const pw.TextStyle(fontSize: 16)),
            );
          }
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Users',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Text(
                      'Total: ${users.length}',
                      style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headers: const ['Email', 'Role', 'Status', 'Department', 'ID Number'],
                data: users.map((user) {
                  return [
                    user['email'] ?? '',
                    user['role'] ?? '',
                    user['status'] ?? '',
                    user['department'] ?? '',
                    user['idNumber'] ?? '',
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    // Work Sessions Section - REMOVED Student Name column
    final sessions = data['sessions'] as List;
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          if (sessions.isEmpty) {
            return pw.Center(
              child: pw.Text('No work session data available.', style: const pw.TextStyle(fontSize: 16)),
            );
          }
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Work Sessions',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Text(
                      'Total: ${sessions.length}',
                      style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
                cellStyle: const pw.TextStyle(fontSize: 7),
                headers: const ['Student Email', 'Hours', 'Status', 'Date', 'Department'],
                data: sessions.map((session) {
                  return [
                    session['studentEmail'] ?? '',
                    formatNumber(session['hours']),
                    session['status'] ?? '',
                    session['date'] ?? '',
                    session['department'] ?? '',
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = "workstudy_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf";

    if (kIsWeb) {
      saveFileWeb(bytes, fileName);
    } else {
      await saveFileOther(bytes, fileName);
    }
  }

  // --- PDF Helper Row (RENAMED to avoid conflict) ---
  pw.Widget _buildPdfSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // --- Excel Generation with Filters (REMOVED Student Name column) ---
  Future<void> _generateExcel(Map<String, dynamic> data) async {
    final workbook = excel.Excel.createExcel();

    String formatNumber(dynamic value, {int decimals = 2}) {
      if (value == null) return '0.00';
      if (value is num) return value.toStringAsFixed(decimals);
      return value.toString();
    }

    // Dashboard Sheet
    final dashboardSheet = workbook['Dashboard'];
    dashboardSheet.appendRow([excel.TextCellValue('WorkStudy Admin Report')]);
    dashboardSheet.appendRow([excel.TextCellValue('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}')]);
    dashboardSheet.appendRow([excel.TextCellValue('Filters: ${_getFilterDescription()}')]);
    dashboardSheet.appendRow([]);
    dashboardSheet.appendRow([excel.TextCellValue('Summary'), excel.TextCellValue('')]);
    dashboardSheet.appendRow([excel.TextCellValue('Total Users'), excel.TextCellValue('${data['totalUsers']}')]);
    dashboardSheet.appendRow([excel.TextCellValue('Total Sessions'), excel.TextCellValue('${data['totalSessions']}')]);
    dashboardSheet.appendRow([excel.TextCellValue('Total Hours'), excel.TextCellValue(formatNumber(data['totalHours']))]);

    // Users Sheet
    final users = data['users'] as List;
    final usersSheet = workbook['Users'];
    if (users.isNotEmpty) {
      final headers = ['Email', 'Role', 'Status', 'Department', 'ID Number'];
      usersSheet.appendRow(headers.map((h) => excel.TextCellValue(h)).toList());
      for (var user in users) {
        usersSheet.appendRow([
          excel.TextCellValue(user['email'] ?? ''),
          excel.TextCellValue(user['role'] ?? ''),
          excel.TextCellValue(user['status'] ?? ''),
          excel.TextCellValue(user['department'] ?? ''),
          excel.TextCellValue(user['idNumber'] ?? ''),
        ]);
      }
    }

    // Work Sessions Sheet - REMOVED Student Name column
    final sessions = data['sessions'] as List;
    final sessionsSheet = workbook['Work Sessions'];
    if (sessions.isNotEmpty) {
      final headers = ['Student Email', 'Hours', 'Status', 'Date', 'Department'];
      sessionsSheet.appendRow(headers.map((h) => excel.TextCellValue(h)).toList());
      for (var session in sessions) {
        sessionsSheet.appendRow([
          excel.TextCellValue(session['studentEmail'] ?? ''),
          excel.TextCellValue(formatNumber(session['hours'])),
          excel.TextCellValue(session['status'] ?? ''),
          excel.TextCellValue(session['date'] ?? ''),
          excel.TextCellValue(session['department'] ?? ''),
        ]);
      }
    }

    final bytes = workbook.save();
    if (bytes == null) throw Exception('Failed to generate Excel file');

    final fileName = "workstudy_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx";

    if (kIsWeb) {
      saveFileWeb(Uint8List.fromList(bytes), fileName);
    } else {
      await saveFileOther(Uint8List.fromList(bytes), fileName);
    }
  }

  void _showCardDetails(String cardType) {
    final Map<String, dynamic> cardData = {
      'title': '',
      'data': [],
      'color': Colors.blue,
    };

    switch (cardType) {
      case 'students':
        cardData['title'] = 'Students (All)';
        cardData['data'] = _studentsEmails;
        cardData['color'] = Colors.blue;
        break;
      case 'supervisors':
        cardData['title'] = 'Supervisors (All)';
        cardData['data'] = _supervisorsEmails;
        cardData['color'] = Colors.purple;
        break;
      case 'pending':
        cardData['title'] = 'Pending Approvals';
        cardData['data'] = _pendingActivities;
        cardData['color'] = Colors.orange;
        break;
      case 'hours':
        cardData['title'] = 'Hours Approved';
        cardData['data'] = _approvedActivities;
        cardData['color'] = Colors.green;
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardData['color'],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cardData['title'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildCardContent(cardType, cardData['data'], cardData['color']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(String cardType, List<dynamic> data, Color color) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: color));
    }

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 60, color: color.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No data available', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withOpacity(0.1),
                foregroundColor: color,
              ),
            ),
          ],
        ),
      );
    }

    if (cardType == 'students' || cardType == 'supervisors') {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: data.length,
        itemBuilder: (context, index) {
          final email = data[index] as String;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(Icons.email_outlined, color: color),
              ),
              title: Text(email, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
              subtitle: Text(
                cardType == 'students' ? 'Student' : 'Supervisor',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          );
        },
      );
    } else if (cardType == 'pending') {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: data.length,
        itemBuilder: (context, index) {
          final user = data[index] as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(Icons.person_add, color: color),
              ),
              title: Text(user['email']?.toString() ?? 'No email', 
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('ID: ${user['idNumber']?.toString() ?? 'No ID'}', 
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  Text('Department: ${user['department']?.toString() ?? 'No department'}', 
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text('Role: ${user['role']?.toString() ?? 'Unknown'}', 
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: data.length,
        itemBuilder: (context, index) {
          final activity = data[index] as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(Icons.check_circle, color: color),
              ),
              title: Text(activity['studentEmail']?.toString() ?? 'No student', 
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('${(activity['hours'] ?? 0.0).toStringAsFixed(2)} hours', 
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.bold)),
                  Text('Department: ${activity['department']?.toString() ?? 'Unknown'}', 
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text('Date: ${activity['date']?.toString() ?? 'No date'}', 
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          );
        },
      );
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
    if (email.isEmpty) return false;
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return regex.hasMatch(email);
  }

  void _showSnack(String message, {Color color = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Center(child: Text(message, style: const TextStyle(color: Colors.white))),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 40, left: 40, right: 40),
      ),
    );
  }

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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: const Text(
                            "WorkStudy",
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
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
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
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
          if (isLoading)
            Container(
              color: Colors.black54.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final bool hasStats = stats.isNotEmpty && stats["totalStudents"] != null;

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.blue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "System Overview",
                    style: TextStyle(color: Colors.blue, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastRefreshTime != null
                        ? "Data last refreshed: ${DateFormat('MMM dd, h:mm a').format(_lastRefreshTime!)}"
                        : "Loading data...",
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _refreshData,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text("Refresh Data"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _showSnack("Tap any card for detailed view", color: Colors.blue),
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text("View Details"),
                          style: TextButton.styleFrom(foregroundColor: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!hasStats && isLoading)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: List.generate(4, (index) => _loadingStatCard()),
              )
            else if (hasStats)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _statCard(Icons.people, "Students", "${stats["totalStudents"]}", Colors.blue, cardType: 'students'),
                  _statCard(Icons.supervisor_account, "Supervisors", "${stats["totalSupervisors"]}", Colors.purple, cardType: 'supervisors'),
                  _statCard(Icons.pending_actions, "Pending", "${stats["pendingApprovals"]}", Colors.orange, cardType: 'pending'),
                  _statCard(Icons.timer, "Hours", "${(stats["totalHoursApproved"] ?? 0.0).toStringAsFixed(2)}h", Colors.green, cardType: 'hours'),
                ],
              ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Hours Summary",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                      ),
                      Icon(Icons.access_time, color: Colors.blue, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "${(stats["totalHoursApproved"] ?? 0.0).toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Total Approved Hours",
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        if ((stats["totalHoursApproved"] ?? 0.0) == 0.0)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "No approved hours yet.",
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Total from ${_approvedActivities.length} approved sessions",
                              style: TextStyle(fontSize: 14, color: Colors.green[700], fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                final sortedUsers = users..sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = parseAnyTimestamp(aData['createdAt']);
                  final bTime = parseAnyTimestamp(bData['createdAt']);
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                final filteredUsers = sortedUsers.where((user) {
                  final userData = user.data() as Map<String, dynamic>;
                  final email = userData['email']?.toString().toLowerCase() ?? '';
                  final role = userData['role']?.toString().toLowerCase() ?? '';
                  final name = userData['name']?.toString().toLowerCase() ?? '';
                  final idNumber = userData['idNumber']?.toString().toLowerCase() ?? '';
                  return email.contains(searchQuery) || role.contains(searchQuery) || 
                         name.contains(searchQuery) || idNumber.contains(searchQuery);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Text('No users found', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (_, i) {
                    final user = filteredUsers[i];
                    final userData = user.data() as Map<String, dynamic>;
                    final userId = user.id;
                    final email = userData['email']?.toString() ?? 'No email';
                    final role = userData['role']?.toString() ?? 'No role';
                    final status = userData['status']?.toString() ?? 'pending';
                    final idNumber = userData['idNumber']?.toString() ?? 'No ID';
                    final department = userData['department']?.toString() ?? 'No department';
                    final createdAt = userData['createdAt'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('ID: $idNumber • Department: $department'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('$role • '),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: status.toLowerCase() == 'approved' ? Colors.green : 
                                           status.toLowerCase() == 'pending' ? Colors.orange : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Joined: ${formatTimestamp(createdAt)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _actionIcon(
                                  icon: Icons.check_circle,
                                  label: "Approve",
                                  color: status.toLowerCase() == 'approved' ? Colors.grey : Colors.green,
                                  onPressed: status.toLowerCase() == 'approved' ? null : () => _approveUser(userId, email),
                                ),
                                _actionIcon(
                                  icon: Icons.cancel,
                                  label: "Decline",
                                  color: status.toLowerCase() == 'declined' ? Colors.grey : Colors.red,
                                  onPressed: status.toLowerCase() == 'declined' ? null : () => _declineUser(userId, email),
                                ),
                                _actionIcon(
                                  icon: Icons.edit,
                                  label: "Edit",
                                  color: Colors.blue,
                                  onPressed: () => _editUserDialog(userData, userId),
                                ),
                                _actionIcon(
                                  icon: Icons.delete,
                                  label: "Delete",
                                  color: Colors.orange,
                                  onPressed: () => _confirmDelete(userId, email),
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

  Widget _buildReportsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _buildExportCard(),
          const SizedBox(height: 16),
          _buildReportSummary(),
        ],
      ),
    );
  }

  Widget _buildExportCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Export Reports",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
            ),
            const SizedBox(height: 4),
            Text(
              _getFilterDescription(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showExportFilterDialog,
              icon: const Icon(Icons.filter_alt),
              label: const Text("Export with Filters"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSummary() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Report Summary",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow("This Month", "${(reportStats["thisMonthHours"] ?? 0.0).toStringAsFixed(2)} hours"),
            _buildSummaryRow("Last Month", "${(reportStats["lastMonthHours"] ?? 0.0).toStringAsFixed(2)} hours"),
            _buildSummaryRow("Total Students", stats["totalStudents"].toString()),
            _buildSummaryRow("Pending Approvals", stats["pendingApprovals"].toString()),
            _buildSummaryRow("Total Hours Approved", "${(stats["totalHoursApproved"] ?? 0.0).toStringAsFixed(2)} hrs"),
            _buildSummaryRow("Avg Hours/Student", "${(reportStats["avgHoursPerStudent"] ?? 0.0).toStringAsFixed(2)} hrs"),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
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

  Widget _loadingStatCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey.withOpacity(0.3)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(width: 40, height: 20, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 4),
            Container(width: 60, height: 14, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String title, String value, Color color, {required String cardType}) {
    return InkWell(
      onTap: () => _showCardDetails(cardType),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Center(child: Icon(icon, color: color, size: 20)),
              ),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Icon(Icons.touch_app, size: 10, color: color.withOpacity(0.6)),
            ],
          ),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
      ),
    );
  }

  Widget _actionIcon({required IconData icon, required String label, required Color color, required VoidCallback? onPressed}) {
    return Column(
      children: [
        IconButton(icon: Icon(icon, color: color), onPressed: onPressed),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // --- User Management Functions ---
  void _showSearchDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Search Users"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter email, name, or role", border: OutlineInputBorder()),
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

  Future<void> _createUserWithEmailAndPassword(String email, String password,
      String role, String department, String idNumber) async {
    try {
      final FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: Firebase.app());
      final UserCredential userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': role,
        'department': department,
        'idNumber': idNumber,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await tempAuth.signOut();
      return;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('This email is already registered');
      } else if (e.code == 'weak-password') {
        throw Exception('Password is too weak');
      } else {
        throw Exception('Failed to create user: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  // ========== UPDATED ADD USER DIALOG WITH ID VALIDATION ==========
  void _addUserDialog(String role) {
    final emailController = TextEditingController();
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController, 
                    decoration: const InputDecoration(
                      labelText: "Email", 
                      border: OutlineInputBorder(),
                      hintText: "e.g., name@daystar.ac.ke",
                    ), 
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: idNumberController, 
                    decoration: const InputDecoration(
                      labelText: "ID Number", 
                      border: OutlineInputBorder(),
                      hintText: "6-14 digits only",
                      helperText: "Must be 6-14 digits (e.g., 12345678)",
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: departmentController, 
                    decoration: const InputDecoration(
                      labelText: "Department", 
                      border: OutlineInputBorder(),
                      hintText: "e.g., Kitchen, Sports, Library",
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
                        icon: Icon(obscureTextAddUser ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setDialogState(() => obscureTextAddUser = !obscureTextAddUser),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text("Cancel")
              ),
              ElevatedButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  final idNumber = idNumberController.text.trim();
                  final department = departmentController.text.trim();
                  final password = passwordController.text.trim();

                  // Validate email
                  if (!_isValidEmail(email)) {
                    Navigator.pop(context);
                    _showSnack("⚠️ Please enter a valid email address.");
                    return;
                  }

                  // Validate ID Number (6-14 digits)
                  if (!_isValidIdNumber(idNumber)) {
                    Navigator.pop(context);
                    _showSnack("⚠️ ID Number must be 6-14 digits only.");
                    return;
                  }

                  if (department.isEmpty) {
                    Navigator.pop(context);
                    _showSnack("⚠️ Please enter a department.");
                    return;
                  }

                  if (password.length < 6) {
                    Navigator.pop(context);
                    _showSnack("⚠️ Password must be at least 6 characters.");
                    return;
                  }

                  Navigator.pop(context);
                  await _showLoadingEffect(() async {
                    try {
                      await _createUserWithEmailAndPassword(email, password, role, department, idNumber);
                      _showSnack("✅ $role added successfully.", color: Colors.green);
                      await _loadAllData();
                    } catch (e) {
                      _showSnack("❌ Error adding user: $e");
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

  // ========== UPDATED EDIT USER DIALOG WITH ID VALIDATION ==========
  void _editUserDialog(Map<String, dynamic> user, String userId) {
    final emailController = TextEditingController(text: user["email"]?.toString() ?? '');
    final idNumberController = TextEditingController(text: user["idNumber"]?.toString() ?? '');
    final departmentController = TextEditingController(text: user["department"]?.toString() ?? '');
    String role = user["role"]?.toString() ?? 'Student';
    final List<String> validRoles = ["Student", "Supervisor"];
    if (!validRoles.contains(role)) role = 'Student';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
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
                      helperText: "6-14 digits only",
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
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
                    items: validRoles.map((String role) => DropdownMenuItem<String>(
                      value: role, 
                      child: Text(role)
                    )).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) setState(() => role = newValue);
                    },
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
                child: const Text("Cancel")
              ),
              ElevatedButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  final idNumber = idNumberController.text.trim();
                  final department = departmentController.text.trim();

                  // Validate email
                  if (!_isValidEmail(email)) {
                    Navigator.pop(context);
                    _showSnack("⚠️ Please enter a valid email address.");
                    return;
                  }

                  // Validate ID Number (6-14 digits)
                  if (!_isValidIdNumber(idNumber)) {
                    Navigator.pop(context);
                    _showSnack("⚠️ ID Number must be 6-14 digits only.");
                    return;
                  }

                  if (department.isEmpty) {
                    Navigator.pop(context);
                    _showSnack("⚠️ Please enter a department.");
                    return;
                  }

                  if (!validRoles.contains(role)) {
                    Navigator.pop(context);
                    _showSnack("⚠️ Please select a valid role.");
                    return;
                  }

                  Navigator.pop(context);
                  await _showLoadingEffect(() async {
                    try {
                      await _firebaseService.updateUser(userId, email, role, department, idNumber);
                      _showSnack("✅ User updated successfully.", color: Colors.green);
                      await _loadAllData();
                    } catch (e) {
                      _showSnack("❌ Error updating user: $e");
                    }
                  });
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _approveUser(String userId, String email) async {
    await _showLoadingEffect(() async {
      try {
        await _firebaseService.updateUserStatus(userId, 'approved');
        _showSnack("✅ $email approved successfully.", color: Colors.green);
        await _loadAllData();
      } catch (e) {
        _showSnack("❌ Error approving user: $e");
      }
    });
  }

  void _declineUser(String userId, String email) async {
    await _showLoadingEffect(() async {
      try {
        await _firebaseService.updateUserStatus(userId, 'declined');
        _showSnack("❌ $email declined.", color: Colors.red);
        await _loadAllData();
      } catch (e) {
        _showSnack("❌ Error declining user: $e");
      }
    });
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
                  final docSnapshot = await _firestore.collection('users').doc(userId).get();
                  if (docSnapshot.exists) {
                    throw Exception('User document still exists after deletion attempt.');
                  }
                  _showSnack("✅ $email removed successfully.", color: Colors.green);
                  await _loadAllData();
                } catch (e) {
                  print('❌ Delete error: $e');
                  _showSnack("❌ Error deleting user: $e", color: Colors.red);
                }
              });
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}

extension on excel.Sheet {
  void setColAutoFit(int i) {}
}