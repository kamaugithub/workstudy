import 'package:flutter/material.dart';
import 'package:workstudy/pages/login.dart';
void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StudentDashboard(),
    ),
  );
}

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool isSessionActive = false;
  String currentSessionDuration = "00:00:00";
  String comment = "";

  // Mock Data
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
      "status": "approved",
      "description": "Student registration assistance",
    },
  ];

  void handleClockIn() {
    setState(() {
      isSessionActive = true;
    });
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
    setState(() {
      comment = "";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Hours Submitted for Supervisor Approval.")),
    );
  }

  void handleExport(String type) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Exporting to $type...")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "WorkStudy",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1e40af), // Daystar Blue
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.grey),
                SizedBox(width: 4),
                Text("Student", style: TextStyle(color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              "Hello $studentName, welcome back! 👋",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              "Ready to track your work hours today?",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Total Hours",
                    totalHoursWorked.toString(),
                    Icons.timer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "This Week",
                    thisWeekHours.toString(),
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Clock In/Out Section
            _buildClockCard(),

            const SizedBox(height: 20),

            // Comment + Submit Section
            _buildCommentCard(),

            const SizedBox(height: 20),

            // Recent Activities
            _buildActivityCard(),

            const SizedBox(height: 20),

            // Export Options
            _buildExportCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: Icon(icon, color: const Color(0xFF1e40af)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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

  Widget _buildClockCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: const [
                Icon(Icons.access_time, color: Color(0xFF1e40af)),
                SizedBox(width: 8),
                Text(
                  "Current Session",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isSessionActive
                  ? "Session in progress"
                  : "Start a new work session",
            ),
            const SizedBox(height: 16),
            if (isSessionActive)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
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
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: "monospace",
                        color: Color(0xFF1e40af),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isSessionActive ? handleClockOut : handleClockIn,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor:
                    isSessionActive ? Colors.red : const Color(0xFF1e40af),
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

  Widget _buildCommentCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                hintText: "Describe the work...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: comment.trim().isEmpty ? null : handleSubmitHours,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF1e40af),
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

  Widget _buildActivityCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: const [
                Icon(Icons.history, color: Color(0xFF1e40af)),
                SizedBox(width: 8),
                Text(
                  "Recent Activities",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Your recent work sessions and approval status",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Column(
              children:
                  recentActivities.map((activity) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
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
                              color: Color(0xFF1e40af),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                side: const BorderSide(color: Color(0xFF1e40af)),
              ),
              child: const Text(
                "View All Activities",
                style: TextStyle(color: Color(0xFF1e40af)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Download your work activity reports",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => handleExport("Excel"),
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
                    onPressed: () => handleExport("Word"),
                    icon: const Icon(
                      Icons.description,
                      color: Color(0xFF1e40af),
                    ),
                    label: const Text(
                      "Export Word",
                      style: TextStyle(color: Color(0xFF1e40af)),
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
