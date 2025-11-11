import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:workstudy/pages/login.dart';
import 'dart:async';

import 'package:workstudy/service/firebase_service.dart';

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

  Map<String, dynamic> stats = {
    "totalStudents": 0,
    "totalSupervisors": 0,
    "pendingApprovals": 0,
    "totalHoursApproved": 0,
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
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

  void _handleExport(String format) async {
    _showLoadingEffect(() async {
      // Simulate export process
      await Future.delayed(const Duration(seconds: 2));
      _showSnack(
        "✅ ${format.toUpperCase()} report generated successfully!",
        color: Colors.green,
      );
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

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Add $role"),
        content: Column(
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
            ),
          ],
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

              if (!_isValidEmail(email) || name.isEmpty) {
                Navigator.pop(context);
                _showSnack("⚠️ Please fill all fields correctly.");
                return;
              }

              Navigator.pop(context);
              await _showLoadingEffect(() async {
                try {
                  await _firebaseService.addUser(email, role, name);
                  _showSnack(
                    "$role added successfully.",
                    color: Colors.greenAccent,
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
      ),
    );
  }

  void _editUserDialog(Map<String, dynamic> user, String userId) {
    final emailController = TextEditingController(text: user["email"] ?? '');
    final nameController = TextEditingController(text: user["name"] ?? '');
    String role = user["role"] ?? 'Student';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit User"),
        content: Column(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final name = nameController.text.trim();

              if (!_isValidEmail(email) || name.isEmpty) {
                Navigator.pop(context);
                _showSnack("⚠️ Please fill all fields correctly.");
                return;
              }

              Navigator.pop(context);
              await _showLoadingEffect(() async {
                try {
                  await _firebaseService.updateUser(userId, email, role, name);
                  _showSnack(
                    "✅ User updated successfully.",
                    color: Colors.greenAccent,
                  );
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
                final filteredUsers = users.where((user) {
                  final userData = user.data() as Map<String, dynamic>;
                  final email =
                      userData['email']?.toString().toLowerCase() ?? '';
                  final role = userData['role']?.toString().toLowerCase() ?? '';
                  final name = userData['name']?.toString().toLowerCase() ?? '';

                  return email.contains(searchQuery) ||
                      role.contains(searchQuery) ||
                      name.contains(searchQuery);
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
              onPressed: () => _handleExport("CSV"),
              icon: const Icon(Icons.download),
              label: const Text("Export CSV Report"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _handleExport("PDF"),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Export PDF Report"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _handleExport("Excel"),
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
            _summaryRow("This Month", "342 hours"),
            _summaryRow("Last Month", "298 hours"),
            _summaryRow("Total Students", stats["totalStudents"].toString()),
            _summaryRow("Avg Hours/Student", "7.6 hrs"),
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
