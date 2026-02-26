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
  String? _expandedCard;
  List<String> _studentsEmails = [];
  List<String> _supervisorsEmails = [];
  List<Map<String, dynamic>> _pendingActivities = [];
  List<Map<String, dynamic>> _approvedActivities = [];

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

  // --- MAIN DATA LOADING METHOD --- with DEBUG LOGS
  Future<void> _loadAllData() async {
    if (_isRefreshing) return;

    setState(() {
      isLoading = true;
      _isRefreshing = true;
    });

    print('🔄 ===== STARTING DATA LOAD =====');

    try {
      await Future.wait([
        _loadDashboardStats(),
        _loadReportStats(),
        _loadEmailLists(),
      ]);
      _lastRefreshTime = DateTime.now();
      print('✅ All data loaded successfully at $_lastRefreshTime');
    } catch (e) {
      print('❌ Error loading all data: $e');
      _showSnack("Error loading dashboard data: $e");
    } finally {
      setState(() {
        isLoading = false;
        _isRefreshing = false;
      });
      print('🔄 ===== DATA LOAD COMPLETE =====');
    }
  }

  // --- COMPREHENSIVE DEBUG METHOD TO CHECK WORK SESSIONS ---
  Future<void> _debugCheckWorkSessions() async {
    setState(() => isLoading = true);
    
    print('\n🔴🔴🔴 DEBUG: Checking all work sessions... 🔴🔴🔴');
    
    try {
      print('\n📊 FETCHING ALL WORK SESSIONS:');
      final allSessions = await _firestore.collection('work_sessions').get();
      print('Total documents in work_sessions: ${allSessions.docs.length}');
      
      if (allSessions.docs.isNotEmpty) {
        print('\n📋 DETAILED SESSION INFORMATION:');
        for (var i = 0; i < allSessions.docs.length; i++) {
          final doc = allSessions.docs[i];
          final data = doc.data();
          print('\n--- Session ${i + 1} (ID: ${doc.id}) ---');
          data.forEach((key, value) {
            print('   $key: $value (${value.runtimeType})');
          });
        }
        
        // Specifically query for "Approved" status (capital A)
        print('\n✅ CHECKING SESSIONS WITH STATUS "Approved":');
        final approvedSessions = await _firestore
            .collection('work_sessions')
            .where('status', isEqualTo: 'Approved')
            .get();
        
        print('Found ${approvedSessions.docs.length} sessions with status "Approved"');
        
        double total = 0.0;
        for (var session in approvedSessions.docs) {
          final data = session.data();
          final hours = data['hours'];
          double hourValue = 0.0;
          if (hours != null) {
            if (hours is int) hourValue = hours.toDouble();
            else if (hours is double) hourValue = hours;
            else if (hours is String) hourValue = double.tryParse(hours) ?? 0.0;
          }
          total += hourValue;
          print('   - Session ${session.id}: $hourValue hours (Student: ${data['studentEmail']})');
        }
        print('💰 TOTAL APPROVED HOURS: $total');
        
        _showSnack('Debug complete! Found ${approvedSessions.docs.length} approved sessions with $total hours', 
            color: approvedSessions.docs.isNotEmpty ? Colors.green : Colors.orange);
      }
      
    } catch (e) {
      print('❌ Error in debug check: $e');
      _showSnack('Debug error: $e', color: Colors.red);
    }
    
    print('\n🔴🔴🔴 DEBUG COMPLETE =====\n');
    setState(() => isLoading = false);
  }

  // Helper method to extract hours from various possible field names
  double _extractHours(Map<String, dynamic> data) {
    // Try different possible field names
    List<String> possibleFields = ['hours', 'hour', 'totalHours', 'approvedHours', 'workHours', 'duration'];
    
    for (var field in possibleFields) {
      if (data.containsKey(field)) {
        final value = data[field];
        if (value != null) {
          if (value is int) {
            return value.toDouble();
          } else if (value is double) {
            return value;
          } else if (value is String) {
            final parsed = double.tryParse(value);
            if (parsed != null) return parsed;
          } else if (value is num) {
            return value.toDouble();
          }
        }
      }
    }
    return 0.0;
  }

  // --- REFRESH DATA WITH DEBOUNCING ---
  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    await _loadAllData();
    _showSnack("Dashboard data refreshed!", color: Colors.green);
  }

  // --- TIMESTAMP UTILITY FUNCTIONS ---

  /// Converts any timestamp format to DateTime
  DateTime? parseAnyTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is int) {
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

  /// Formats timestamp to readable format
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

  // Load dashboard statistics - FIXED to use correct "Approved" status
  Future<void> _loadDashboardStats() async {
    try {
      print('📊 Loading dashboard stats...');

      // Fetch all users to get counts
      final allUsers = await _firestore.collection('users').get();
      print('👥 Total users in database: ${allUsers.docs.length}');

      int totalStudents = 0;
      int totalSupervisors = 0;
      int pendingApprovals = 0;
      int otherUsers = 0;

      for (var doc in allUsers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['role']?.toString() ?? '';
        final status = data['status']?.toString()?.toLowerCase() ?? '';

        if (role == 'Student') {
          totalStudents++;
          if (status == 'pending') pendingApprovals++;
        } else if (role == 'Supervisor') {
          totalSupervisors++;
          if (status == 'pending') pendingApprovals++;
        } else {
          otherUsers++;
          if (status == 'pending') pendingApprovals++;
        }
      }

      // IMPORTANT: Query with exact case "Approved" (capital A) as shown in your database
      print('🔍 Fetching ALL approved work sessions with status "Approved"...');
      final approvedSessions = await _firestore
          .collection('work_sessions')
          .where('status', isEqualTo: 'Approved')  // Note: Capital A
          .get();

      print('⏰ Approved work sessions found: ${approvedSessions.docs.length}');

      // Calculate total hours approved
      double totalHoursApproved = 0.0;
      List<String> approvedSessionIds = [];
      
      if (approvedSessions.docs.isNotEmpty) {
        for (var session in approvedSessions.docs) {
          final data = session.data() as Map<String, dynamic>;
          final hours = data['hours'];
          final studentEmail = data['studentEmail'] ?? 'Unknown';
          final date = data['date'] ?? 'No date';
          
          double hourValue = 0.0;
          if (hours != null) {
            if (hours is int) {
              hourValue = hours.toDouble();
            } else if (hours is double) {
              hourValue = hours;
            } else if (hours is String) {
              hourValue = double.tryParse(hours) ?? 0.0;
            }
            
            totalHoursApproved += hourValue;
            approvedSessionIds.add(session.id);
            print('   ✅ Session: $studentEmail - $hourValue hours on $date');
          }
        }
      } else {
        print('⚠️ No approved sessions found with status "Approved"');
      }

      print('📈 Calculated stats:');
      print('- Total Students (all): $totalStudents');
      print('- Total Supervisors (all): $totalSupervisors');
      print('- Other Users: $otherUsers');
      print('- Pending Approvals: $pendingApprovals');
      print('- Total Hours Approved: $totalHoursApproved (from ${approvedSessions.docs.length} sessions)');
      print('- Approved Session IDs: $approvedSessionIds');

      setState(() {
        stats = {
          "totalStudents": totalStudents,
          "totalSupervisors": totalSupervisors,
          "pendingApprovals": pendingApprovals,
          "totalHoursApproved": totalHoursApproved,
          "totalUsers": allUsers.docs.length,
        };
      });
      
      print('✅ Dashboard stats updated with $totalHoursApproved total hours');
    } catch (e) {
      print('❌ Error loading dashboard stats: $e');
      print('Stack trace: ${e.toString()}');
      _showSnack('Error loading stats: $e');
    }
  }

  // Load report statistics - FIXED with correct case
  Future<void> _loadReportStats() async {
    try {
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);

      print('📅 Loading report stats for:');
      print('   - Current month: ${now.year}-${now.month}');
      print('   - Last month: ${lastMonthStart.year}-${lastMonthStart.month}');

      // Fetch ALL approved work sessions with correct case "Approved"
      final allApprovedSessions = await _firestore
          .collection('work_sessions')
          .where('status', isEqualTo: 'Approved')  // Note: Capital A
          .get();

      print('📋 Total approved sessions: ${allApprovedSessions.docs.length}');

      double thisMonthHours = 0.0;
      double lastMonthHours = 0.0;
      int thisMonthCount = 0;
      int lastMonthCount = 0;

      for (var session in allApprovedSessions.docs) {
        final data = session.data() as Map<String, dynamic>;
        final submittedAt = parseAnyTimestamp(data['submittedAt']);
        final hours = data['hours'];
        final studentEmail = data['studentEmail'];

        if (submittedAt != null && hours != null) {
          double hourValue = 0.0;
          if (hours is int) hourValue = hours.toDouble();
          else if (hours is double) hourValue = hours;
          else if (hours is String) hourValue = double.tryParse(hours) ?? 0.0;

          // Check if this month
          if (submittedAt.year == now.year && submittedAt.month == now.month) {
            thisMonthHours += hourValue;
            thisMonthCount++;
            print('   📅 This month session: $studentEmail - $hourValue');
          }
          // Check if last month
          else if (submittedAt.year == lastMonthStart.year &&
              submittedAt.month == lastMonthStart.month) {
            lastMonthHours += hourValue;
            lastMonthCount++;
            print('   📅 Last month session: $studentEmail - $hourValue');
          }
        }
      }

      // Get total active students (with approved status)
      final activeStudents = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Student')
          .where('status', isEqualTo: 'approved')
          .get();

      final totalActiveStudents = activeStudents.docs.length;
      final avgHours = totalActiveStudents > 0
          ? (thisMonthHours / totalActiveStudents)
          : 0.0;

      print('📊 Calculated report stats:');
      print('- This month hours: $thisMonthHours (from $thisMonthCount sessions)');
      print('- Last month hours: $lastMonthHours (from $lastMonthCount sessions)');
      print('- Active students: $totalActiveStudents');
      print('- Avg hours/student: $avgHours');

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
      setState(() {
        reportStats = {
          "thisMonthHours": 0.0,
          "lastMonthHours": 0.0,
          "avgHoursPerStudent": 0.0,
          "thisMonthCount": 0,
          "lastMonthCount": 0,
        };
      });
    }
  }

  // Load email lists for clickable cards - FIXED with correct case
  Future<void> _loadEmailLists() async {
    try {
      print('📧 Loading email lists...');

      // Load ALL students
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Student')
          .get();

      print('🎓 All students found: ${studentsSnapshot.docs.length}');
      _studentsEmails = studentsSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final email = data['email']?.toString().trim() ?? '';
            return email;
          })
          .where((email) => email.isNotEmpty && _isValidEmail(email))
          .toList();

      // Load ALL supervisors
      final supervisorsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Supervisor')
          .get();

      print('👨‍🏫 All supervisors found: ${supervisorsSnapshot.docs.length}');
      _supervisorsEmails = supervisorsSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final email = data['email']?.toString().trim() ?? '';
            return email;
          })
          .where((email) => email.isNotEmpty && _isValidEmail(email))
          .toList();

      // Load ALL pending users
      final pendingUsersSnapshot = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .get();

      print('⏳ Pending users found: ${pendingUsersSnapshot.docs.length}');
      _pendingActivities = pendingUsersSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'email': data['email']?.toString().trim() ?? 'No email',
          'role': data['role']?.toString() ?? 'Unknown',
          'idNumber': data['idNumber']?.toString() ?? 'No ID',
          'department': data['department']?.toString() ?? 'No department',
          'status': data['status']?.toString() ?? 'pending',
          'createdAt': data['createdAt'],
        };
      }).toList();

      // Load approved activities for hours calculation - FIXED with "Approved" (capital A)
      print('✅ Loading approved work sessions for card details...');
      final approvedSessions = await _firestore
          .collection('work_sessions')
          .where('status', isEqualTo: 'Approved')  // Note: Capital A
          .get();

      print('✅ Approved work sessions: ${approvedSessions.docs.length}');
      _approvedActivities = approvedSessions.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final hours = data['hours'];
        double hourValue = 0.0;
        
        if (hours != null) {
          if (hours is int) hourValue = hours.toDouble();
          else if (hours is double) hourValue = hours;
          else if (hours is String) hourValue = double.tryParse(hours) ?? 0.0;
        }
        
        return {
          'studentEmail': data['studentEmail']?.toString().trim() ?? 'No email',
          'hours': hourValue,
          'date': data['date']?.toString() ?? 'No date',
          'studentName': data['studentName']?.toString() ?? 'Unknown',
          'department': data['department']?.toString() ?? 'Unknown',
          'supervisorEmail': data['supervisorEmail']?.toString().trim() ?? 'No supervisor',
        };
      }).toList();

      print('📊 Summary:');
      print('- Students (all): ${_studentsEmails.length}');
      print('- Supervisors (all): ${_supervisorsEmails.length}');
      print('- Pending users: ${_pendingActivities.length}');
      print('- Approved sessions: ${_approvedActivities.length}');
      
      // Print approved session details
      for (var activity in _approvedActivities) {
        print('   - ${activity['studentEmail']}: ${activity['hours']}h');
      }
    } catch (e) {
      print('❌ Error loading email lists: $e');
      _studentsEmails = [];
      _supervisorsEmails = [];
      _pendingActivities = [];
      _approvedActivities = [];
    }
  }

  // Show modal for card details
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
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
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
        );
      },
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
              title: Text(user['email'] ?? 'No email', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('ID: ${user['idNumber'] ?? 'No ID'}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  Text('Department: ${user['department'] ?? 'No department'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text('Role: ${user['role'] ?? 'Unknown'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
              title: Text(activity['studentEmail'] ?? 'No student', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('${activity['hours']?.toStringAsFixed(2) ?? '0.00'} hours', 
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.bold)),
                  Text('Department: ${activity['department'] ?? 'Unknown'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text('Date: ${activity['date'] ?? 'No date'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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

  // --- Overview Tab --- Shows total approved hours
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _debugCheckWorkSessions,
                          icon: const Icon(Icons.bug_report, size: 18),
                          label: const Text("Debug DB"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
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
                              "No approved hours yet. Hours will appear when work sessions are approved.",
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
                    final email = userData['email'] ?? 'No email';
                    final role = userData['role'] ?? 'No role';
                    final status = userData['status'] ?? 'pending';
                    final idNumber = userData['idNumber'] ?? 'No ID';
                    final department = userData['department'] ?? 'No department';
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
                                    color: status == 'approved' ? Colors.green : 
                                           status == 'pending' ? Colors.orange : Colors.red,
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
                                  color: status == 'approved' ? Colors.grey : Colors.green,
                                  onPressed: status == 'approved' ? null : () => _approveUser(userId, email),
                                ),
                                _actionIcon(
                                  icon: Icons.cancel,
                                  label: "Decline",
                                  color: status == 'declined' ? Colors.grey : Colors.red,
                                  onPressed: status == 'declined' ? null : () => _declineUser(userId, email),
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
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  TextField(controller: idNumberController, decoration: const InputDecoration(labelText: "ID Number", border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: departmentController, decoration: const InputDecoration(labelText: "Department", border: OutlineInputBorder())),
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  final idNumber = idNumberController.text.trim();
                  final department = departmentController.text.trim();
                  final password = passwordController.text.trim();

                  if (!_isValidEmail(email) || idNumber.isEmpty || department.isEmpty || password.length < 6) {
                    Navigator.pop(context);
                    _showSnack("⚠️ Please fill all fields correctly. Password must be at least 6 characters.");
                    return;
                  }

                  Navigator.pop(context);
                  await _showLoadingEffect(() async {
                    try {
                      await _createUserWithEmailAndPassword(email, password, role, department, idNumber);
                      _showSnack("$role added successfully. They can now login with the provided credentials.", color: Colors.green);
                      await _loadAllData();
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

  void _approveUser(String userId, String email) async {
    await _showLoadingEffect(() async {
      try {
        await _firebaseService.updateUserStatus(userId, 'approved');
        _showSnack("$email approved successfully.", color: Colors.green);
        await _loadAllData();
      } catch (e) {
        _showSnack("Error approving user: $e");
      }
    });
  }

  void _declineUser(String userId, String email) async {
    await _showLoadingEffect(() async {
      try {
        await _firebaseService.updateUserStatus(userId, 'declined');
        _showSnack("$email declined.", color: Colors.red);
        await _loadAllData();
      } catch (e) {
        _showSnack("Error declining user: $e");
      }
    });
  }

  void _editUserDialog(Map<String, dynamic> user, String userId) {
    final emailController = TextEditingController(text: user["email"] ?? '');
    final idNumberController = TextEditingController(text: user["idNumber"] ?? '');
    final departmentController = TextEditingController(text: user["department"] ?? '');
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
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  TextField(controller: idNumberController, decoration: const InputDecoration(labelText: "ID Number", border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: departmentController, decoration: const InputDecoration(labelText: "Department", border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    items: validRoles.map((String role) => DropdownMenuItem<String>(value: role, child: Text(role))).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) setState(() => role = newValue);
                    },
                    decoration: const InputDecoration(labelText: "Role", border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  final idNumber = idNumberController.text.trim();
                  final department = departmentController.text.trim();

                  if (!_isValidEmail(email) || idNumber.isEmpty || department.isEmpty) {
                    Navigator.pop(context);
                    _showSnack("⚠️ Please fill all fields correctly.");
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
                      _showSnack("Error updating user: $e");
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

  void _confirmDelete(String userId, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User"),
        content: Text("Are you sure you want to remove $email?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _showLoadingEffect(() async {
                try {
                  await _firebaseService.deleteUser(userId);
                  _showSnack("$email removed successfully.", color: Colors.green);
                  await _loadAllData();
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

  // --- Export Functions ---
  Future<List<Map<String, dynamic>>> _fetchReportData() async {
    try {
      final usersSnapshot = await _firestore.collection('users').orderBy('createdAt', descending: true).get();
      final users = usersSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'email': data['email']?.toString() ?? '',
          'role': data['role']?.toString() ?? '',
          'status': data['status']?.toString() ?? '',
          'department': data['department']?.toString() ?? '',
          'idNumber': data['idNumber']?.toString() ?? '',
          'createdAt': formatTimestampForExport(data['createdAt']),
        };
      }).toList();

      final sessionsSnapshot = await _firestore.collection('work_sessions').orderBy('submittedAt', descending: true).get();
      print('🔍 Fetching work sessions... Found ${sessionsSnapshot.docs.length} sessions');

      final sessions = sessionsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'studentId': data['studentId']?.toString() ?? '',
          'studentEmail': data['studentEmail']?.toString() ?? '',
          'hours': _extractHours(data),
          'status': data['status']?.toString() ?? '',
          'reportDetails': data['reportDetails']?.toString() ?? '',
          'date': data['date']?.toString() ?? '',
          'department': data['department']?.toString() ?? '',
          'submittedAt': formatTimestampForExport(data['submittedAt']),
        };
      }).toList();

      print('✅ Users: ${users.length}, Sessions: ${sessions.length}');
      return [
        {'type': 'users', 'data': users},
        {'type': 'work_sessions', 'data': sessions},
      ];
    } catch (e) {
      print('❌ Error fetching report data: $e');
      throw Exception('Failed to fetch report data: $e');
    }
  }

  Future<void> _exportPDF(String format) async {
    await _showLoadingEffect(() async {
      try {
        final reportData = await _fetchReportData();
        final pdf = pw.Document();

        for (var section in reportData) {
          final data = section['data'] as List<Map<String, dynamic>>;
          if (data.isEmpty) {
            print('⚠️ No data for PDF ${section['type']}');
            continue;
          }

          final headers = data.first.keys.toList();
          final tableData = data.map((row) => headers.map((header) => row[header]?.toString() ?? '').toList()).toList();

          pdf.addPage(
            pw.Page(
              margin: const pw.EdgeInsets.all(20),
              build: (context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 40,
                          height: 40,
                          decoration: pw.BoxDecoration(color: PdfColors.blue500, shape: pw.BoxShape.circle),
                          child: pw.Center(child: pw.Text("WS", style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14))),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("WORKSTUDY", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                            pw.Text("Admin ${section['type']} Report", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 15),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(5)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Generated on: ${formatTimestampForExport(DateTime.now())}", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          pw.Text("Total Records: ${data.length}", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text("${section['type'].replaceAll('_', ' ').toUpperCase()}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.SizedBox(height: 10),
                    pw.Table.fromTextArray(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                      headerDecoration: pw.BoxDecoration(color: PdfColors.blue700),
                      cellStyle: pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
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
        final fileName = "workstudy_admin_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf";

        if (kIsWeb) {
          saveFileWeb(bytes, fileName);
          _showSnack("✅ PDF report download initiated!", color: Colors.green);
        } else {
          final path = await saveFileOther(bytes, fileName);
          _showSnack("✅ PDF report exported to: $path", color: Colors.green);
        }
      } catch (e) {
        print('❌ PDF export error: $e');
        _showSnack("PDF export failed: $e");
      }
    });
  }

  Future<void> _exportExcel(String format) async {
    await _showLoadingEffect(() async {
      try {
        final reportData = await _fetchReportData();
        final workbook = excel.Excel.createExcel();

        for (var section in reportData) {
          final sheetName = section['type'] == 'work_sessions' ? 'Work Sessions' : 'Users';
          final sheet = workbook[sheetName];
          final data = section['data'] as List<Map<String, dynamic>>;

          if (data.isEmpty) continue;

          final headers = data.first.keys.toList();
          final headerRow = headers.map((h) => excel.TextCellValue(h)).toList();
          sheet.appendRow(headerRow);

          for (var row in data) {
            final dataRow = <excel.CellValue>[];
            for (var header in headers) {
              final value = row[header]?.toString() ?? '';
              dataRow.add(excel.TextCellValue(value));
            }
            sheet.appendRow(dataRow);
          }

          for (var i = 0; i < headers.length; i++) {
            sheet.setColAutoFit(i);
          }
        }

        final bytes = workbook.save();
        if (bytes == null) {
          _showSnack("Failed to generate Excel file");
          return;
        }

        final fileName = "workstudy_admin_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx";

        if (kIsWeb) {
          saveFileWeb(Uint8List.fromList(bytes), fileName);
          _showSnack("✅ Excel report download initiated!", color: Colors.green);
        } else {
          final path = await saveFileOther(Uint8List.fromList(bytes), fileName);
          _showSnack("✅ Excel report exported to: $path", color: Colors.green);
        }
      } catch (e) {
        print('❌ Excel export error: $e');
        _showSnack("Excel export failed: $e");
      }
    });
  }

  Widget _exportCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Export Reports", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: () => _exportPDF("PDF"), icon: const Icon(Icons.picture_as_pdf), label: const Text("Export PDF Report")),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: () => _exportExcel("Excel"), icon: const Icon(Icons.table_chart), label: const Text("Export Excel Report")),
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
            const Text("Report Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            const SizedBox(height: 12),
            _summaryRow("This Month", "${(reportStats["thisMonthHours"] ?? 0.0).toStringAsFixed(2)} hours"),
            _summaryRow("Last Month", "${(reportStats["lastMonthHours"] ?? 0.0).toStringAsFixed(2)} hours"),
            _summaryRow("Total Students", stats["totalStudents"].toString()),
            _summaryRow("Pending Approvals", stats["pendingApprovals"].toString()),
            _summaryRow("Total Hours Approved", "${(stats["totalHoursApproved"] ?? 0.0).toStringAsFixed(2)} hrs"),
            _summaryRow("Avg Hours/Student (This Month)", "${(reportStats["avgHoursPerStudent"] ?? 0.0).toStringAsFixed(2)} hrs"),
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

extension on excel.Sheet {
  void setColAutoFit(int i) {}
}