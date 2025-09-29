import 'package:flutter/material.dart';
import 'package:workstudy/pages/login.dart';
class adminDashboard extends StatefulWidget {
  const adminDashboard({super.key});

  @override
  State<adminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<adminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final stats = {
    "totalStudents": 45,
    "totalSupervisors": 8,
    "pendingApprovals": 12,
    "totalHoursApproved": 1247,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _handleExport(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Generating ${format.toUpperCase()} report..."),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          Icon(Icons.security, color: Colors.blue),
          SizedBox(width: 8),
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "Super Admin",
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Users"),
            Tab(text: "Reports"),
          ],
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.black54,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildOverviewTab(), _buildUsersTab(), _buildReportsTab()],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Welcome Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blueAccent],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Admin  🔧",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "System overview and management controls",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _statCard(
                Icons.people,
                "Total Students",
                stats["totalStudents"].toString(),
                Colors.blue,
              ),
              _statCard(
                Icons.verified_user,
                "Total Supervisors",
                stats["totalSupervisors"].toString(),
                Colors.purple,
              ),
              _statCard(
                Icons.access_time,
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

  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  onPressed: () {},
                  label: const Text("Add Student"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.supervisor_account),
                  onPressed: () {},
                  label: const Text("Add Supervisor"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: const [
                _userTile("John Doe", "Student • Computer Science"),
                _userTile("Dr. Jane Smith", "Supervisor • Engineering Dept"),
                _userTile("Alice Johnson", "Student • Business Studies"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 1,
        childAspectRatio: 1.2,
        children: [_exportCard(), _reportSummary()],
      ),
    );
  }

  Widget _statCard(IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
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
              onPressed: () => _handleExport("csv"),
              icon: const Icon(Icons.download),
              label: const Text("Export CSV Report"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _handleExport("pdf"),
              icon: const Icon(Icons.download),
              label: const Text("Export PDF Report"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _handleExport("excel"),
              icon: const Icon(Icons.download),
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

class _userTile extends StatelessWidget {
  final String name;
  final String subtitle;
  const _userTile(this.name, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: OutlinedButton(onPressed: () {}, child: const Text("Edit")),
      ),
    );
  }
}
