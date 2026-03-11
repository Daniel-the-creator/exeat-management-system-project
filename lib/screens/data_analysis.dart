import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:exeat_system/model/request_model.dart';

// ─────────────────────────────────────────────
// Helper / local data classes
// ─────────────────────────────────────────────

class StudentExeatSummary {
  final String studentId;
  final String name;
  final String matric;
  final String department;
  final String hall;
  final int totalExeats;
  final int totalDays;
  final int approvedExeats;
  final int pendingExeats;
  final int rejectedExeats;
  final DateTime? lastExeatDate;
  final String? profileImage;

  StudentExeatSummary({
    required this.studentId,
    required this.name,
    required this.matric,
    required this.department,
    required this.hall,
    required this.totalExeats,
    required this.totalDays,
    required this.approvedExeats,
    required this.pendingExeats,
    required this.rejectedExeats,
    this.lastExeatDate,
    this.profileImage,
  });

  String get lastExeatLabel {
    if (lastExeatDate == null) return 'No exeat yet';
    final diff = DateTime.now().difference(lastExeatDate!);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 14) return '1 week ago';
    return '${(diff.inDays / 7).round()} weeks ago';
  }

  String get statusLabel => pendingExeats > 0 ? 'Active' : 'Inactive';
}

// ─────────────────────────────────────────────
// Utility: parse days between two date strings
// ─────────────────────────────────────────────

int _parseDays(String leaveDate, String returnDate) {
  try {
    final leave = DateTime.parse(leaveDate);
    final ret = DateTime.parse(returnDate);
    final diff = ret.difference(leave).inDays;
    return diff > 0 ? diff : 1;
  } catch (_) {
    return 1;
  }
}

// ─────────────────────────────────────────────
// Students Exeat List Screen (Main entry)
// ─────────────────────────────────────────────

class StudentsExeatListScreen extends StatefulWidget {
  const StudentsExeatListScreen({super.key});

  @override
  State<StudentsExeatListScreen> createState() =>
      _StudentsExeatListScreenState();
}

class _StudentsExeatListScreenState extends State<StudentsExeatListScreen> {
  String searchQuery = '';
  String filterBy = 'All';
  String sortBy = 'Name';
  bool _isSearching = false;

  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Aggregate all requests into per-student summaries
  List<StudentExeatSummary> _buildSummaries(List<RequestModel> requests) {
    final Map<String, List<RequestModel>> grouped = {};
    for (final r in requests) {
      grouped.putIfAbsent(r.studentId, () => []).add(r);
    }

    return grouped.entries.map((entry) {
      final list = entry.value;
      final first = list.first;
      int totalDays = 0;
      int approved = 0, pending = 0, rejected = 0;
      DateTime? lastDate;

      for (final r in list) {
        final days = _parseDays(r.leaveDate, r.returnDate);
        totalDays += days;
        if (r.status == 'approved') approved++;
        if (r.status.contains('pending')) pending++;
        if (r.status == 'rejected') rejected++;
        final created = r.createdAt.toDate();
        if (lastDate == null || created.isAfter(lastDate)) {
          lastDate = created;
        }
      }

      return StudentExeatSummary(
        studentId: entry.key,
        name: first.studentName,
        matric: first.studentMatric,
        department: first.departmentId ?? '',
        hall: first.hallId ?? '',
        totalExeats: list.length,
        totalDays: totalDays,
        approvedExeats: approved,
        pendingExeats: pending,
        rejectedExeats: rejected,
        lastExeatDate: lastDate,
      );
    }).toList();
  }

  List<StudentExeatSummary> _applyFiltersAndSort(
      List<StudentExeatSummary> students) {
    List<StudentExeatSummary> filtered = students.where((s) {
      final q = searchQuery.toLowerCase();
      final matchesSearch = s.name.toLowerCase().contains(q) ||
          s.matric.toLowerCase().contains(q) ||
          s.department.toLowerCase().contains(q);

      final matchesFilter = filterBy == 'All' ||
          (filterBy == 'Active' && s.statusLabel == 'Active') ||
          (filterBy == 'Inactive' && s.statusLabel == 'Inactive');

      return matchesSearch && matchesFilter;
    }).toList();

    filtered.sort((a, b) {
      switch (sortBy) {
        case 'Name':
          return a.name.compareTo(b.name);
        case 'Days (High to Low)':
          return b.totalDays.compareTo(a.totalDays);
        case 'Days (Low to High)':
          return a.totalDays.compareTo(b.totalDays);
        case 'Exeats (High to Low)':
          return b.totalExeats.compareTo(a.totalExeats);
        default:
          return a.name.compareTo(b.name);
      }
    });

    return filtered;
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildFilterSheet(),
    );
  }

  Widget _buildFilterSheet() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filter & Sort',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Filter by Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ['All', 'Active', 'Inactive'].map((s) {
                return FilterChip(
                  label: Text(s),
                  selected: filterBy == s,
                  onSelected: (sel) {
                    setState(() => filterBy = sel ? s : 'All');
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Sort by',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...[
              'Name',
              'Days (High to Low)',
              'Days (Low to High)',
              'Exeats (High to Low)',
            ].map((opt) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Radio<String>(
                  value: opt,
                  groupValue: sortBy,
                  onChanged: (v) {
                    setState(() => sortBy = v!);
                    Navigator.pop(context);
                  },
                ),
                title: Text(opt),
                onTap: () {
                  setState(() => sortBy = opt);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search students...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => setState(() => searchQuery = v),
              )
            : const Text('Student Exeat Analytics',
                style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff060121),
        elevation: 0,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() {
                _isSearching = false;
                searchQuery = '';
                _searchController.clear();
              }),
            )
          else
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => setState(() => _isSearching = true),
            ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () => _showFilters(context),
            tooltip: 'Filter & Sort',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: () => Get.to(() => const OverallAnalyticsDashboard()),
            tooltip: 'Overall Analytics',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final allRequests =
              docs.map((d) => RequestModel.fromMap(d.data(), d.id)).toList();

          final summaries = _buildSummaries(allRequests);
          final filtered = _applyFiltersAndSort(summaries);

          final totalDays = summaries.fold(0, (acc, s) => acc + s.totalDays);
          final totalExeats =
              summaries.fold(0, (acc, s) => acc + s.totalExeats);
          final avgDays =
              summaries.isEmpty ? 0.0 : totalDays / summaries.length;

          return Column(
            children: [
              // Summary header bar
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xff060121), Color(0xff1a0f3e)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: _buildStat(
                                    'Total Students',
                                    '${summaries.length}',
                                    Icons.people_outline,
                                    Colors.blue.shade300)),
                            _divider(),
                            Expanded(
                                child: _buildStat(
                                    'Total Days',
                                    '$totalDays',
                                    Icons.calendar_today,
                                    Colors.green.shade300)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(
                              color: Colors.white.withOpacity(0.1),
                              thickness: 1),
                        ),
                        Row(
                          children: [
                            Expanded(
                                child: _buildStat(
                                    'Total Exeats',
                                    '$totalExeats',
                                    Icons.logout,
                                    Colors.orange.shade300)),
                            _divider(),
                            Expanded(
                                child: _buildStat(
                                    'Avg Days',
                                    avgDays.toStringAsFixed(1),
                                    Icons.trending_up,
                                    Colors.purple.shade300)),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                          child: _buildStat(
                              'Total Students',
                              '${summaries.length}',
                              Icons.people_outline,
                              Colors.blue.shade300)),
                      _divider(),
                      Expanded(
                          child: _buildStat('Total Days', '$totalDays',
                              Icons.calendar_today, Colors.green.shade300)),
                      _divider(),
                      Expanded(
                          child: _buildStat('Total Exeats', '$totalExeats',
                              Icons.logout, Colors.orange.shade300)),
                      _divider(),
                      Expanded(
                          child: _buildStat(
                              'Avg Days',
                              avgDays.toStringAsFixed(1),
                              Icons.trending_up,
                              Colors.purple.shade300)),
                    ],
                  );
                }),
              ),

              // Quick filters
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _quickFilter('All', 'All'),
                      _quickFilter('Active', 'Active'),
                      _quickFilter('Inactive', 'Inactive'),
                    ],
                  ),
                ),
              ),

              // List header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Students (${filtered.length})',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff060121))),
                    Text('Sorted by: $sortBy',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),

              // Student cards
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _buildStudentCard(filtered[i], i),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3));

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 6),
      Text(value,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8)),
          textAlign: TextAlign.center),
    ]);
  }

  Widget _quickFilter(String label, String value) {
    final isSelected = filterBy == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (sel) => setState(() => filterBy = sel ? value : 'All'),
        backgroundColor: Colors.grey[100],
        selectedColor: const Color(0xff060121),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentExeatSummary student, int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200 + (index * 50)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.to(() => StudentDetailAnalyticsScreen(
                studentId: student.studentId,
                studentName: student.name,
              )),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.indigo[100],
                        child: student.profileImage != null &&
                                student.profileImage!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(student.profileImage!,
                                    fit: BoxFit.cover))
                            : Text(
                                student.name
                                    .split(' ')
                                    .map((n) => n.isNotEmpty ? n[0] : '')
                                    .take(2)
                                    .join(),
                                style: TextStyle(
                                    color: Colors.indigo[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: student.statusLabel == 'Active'
                                ? Colors.green
                                : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(student.matric,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(student.lastExeatLabel,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                        ]),
                      ],
                    ),
                  ),

                  // Stats
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statBadge('${student.totalDays}d', Icons.calendar_today,
                          Colors.blue),
                      const SizedBox(height: 5),
                      _statBadge('${student.totalExeats} exeats', Icons.logout,
                          Colors.green),
                    ],
                  ),

                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
              searchQuery.isEmpty
                  ? 'No students found'
                  : 'No matching students',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff060121))),
          const SizedBox(height: 8),
          Text(
              searchQuery.isEmpty
                  ? 'No exeat requests have been submitted yet'
                  : 'Try adjusting your search or filters',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center),
          if (searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                searchQuery = '';
                _searchController.clear();
              }),
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Search'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff060121),
                  foregroundColor: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Overall Analytics Dashboard
// ─────────────────────────────────────────────

class OverallAnalyticsDashboard extends StatelessWidget {
  const OverallAnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Overall Analytics',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff060121),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore.collection('requests').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          final requests =
              docs.map((d) => RequestModel.fromMap(d.data(), d.id)).toList();

          // Compute stats
          final total = requests.length;
          final approved = requests.where((r) => r.status == 'approved').length;
          final rejected = requests.where((r) => r.status == 'rejected').length;
          final pending =
              requests.where((r) => r.status.contains('pending')).length;

          // Monthly breakdown (last 6 months)
          final now = DateTime.now();
          final Map<String, int> monthlyCount = {};
          for (int i = 5; i >= 0; i--) {
            final m = DateTime(now.year, now.month - i, 1);
            final key =
                '${_monthShort(m.month)} ${m.year != now.year ? m.year : ''}';
            monthlyCount[key.trim()] = 0;
          }
          for (final r in requests) {
            final d = r.createdAt.toDate();
            final diff = (now.year - d.year) * 12 + (now.month - d.month);
            if (diff >= 0 && diff < 6) {
              final key =
                  '${_monthShort(d.month)} ${d.year != now.year ? d.year : ''}';
              final k = key.trim();
              if (monthlyCount.containsKey(k)) {
                monthlyCount[k] = monthlyCount[k]! + 1;
              }
            }
          }

          // Reason breakdown
          final Map<String, int> reasons = {};
          for (final r in requests) {
            final cleaned = r.reason.trim().isEmpty ? 'Other' : r.reason.trim();
            final key =
                cleaned.length > 20 ? '${cleaned.substring(0, 20)}…' : cleaned;
            reasons[key] = (reasons[key] ?? 0) + 1;
          }
          // Keep top 5
          final sortedReasons = reasons.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topReasons = Map.fromEntries(sortedReasons.take(5));

          final monthKeys = monthlyCount.keys.toList();
          final monthValues =
              monthKeys.map((k) => monthlyCount[k]!.toDouble()).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                LayoutBuilder(builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 600;
                  if (isSmall) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: _overallStatCard('Total', total,
                                    Icons.list_alt, Colors.blue)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _overallStatCard('Approved', approved,
                                    Icons.check_circle, Colors.green)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                                child: _overallStatCard('Pending', pending,
                                    Icons.hourglass_empty, Colors.orange)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _overallStatCard('Rejected', rejected,
                                    Icons.cancel, Colors.red)),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                          child: _overallStatCard(
                              'Total', total, Icons.list_alt, Colors.blue)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _overallStatCard('Approved', approved,
                              Icons.check_circle, Colors.green)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _overallStatCard('Pending', pending,
                              Icons.hourglass_empty, Colors.orange)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _overallStatCard(
                              'Rejected', rejected, Icons.cancel, Colors.red)),
                    ],
                  );
                }),
                const SizedBox(height: 20),

                // Monthly requests bar chart
                _chartCard(
                  'Monthly Requests (Last 6 Months)',
                  SizedBox(
                    height: 240,
                    child: monthValues.every((v) => v == 0)
                        ? const Center(child: Text('No data available'))
                        : Padding(
                            padding: const EdgeInsets.only(top: 16, right: 8),
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                gridData: const FlGridData(
                                    show: true, drawVerticalLine: false),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(
                                      sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 32,
                                          interval: 1)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (v, _) {
                                        final i = v.toInt();
                                        if (i >= 0 && i < monthKeys.length) {
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(monthKeys[i],
                                                style: const TextStyle(
                                                    fontSize: 10)),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                  ),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: monthValues.asMap().entries.map((e) {
                                  return BarChartGroupData(x: e.key, barRods: [
                                    BarChartRodData(
                                      toY: e.value,
                                      color: const Color(0xff060121),
                                      width: 20,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(5)),
                                    ),
                                  ]);
                                }).toList(),
                                minY: 0,
                              ),
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Status Pie Chart
                if (total > 0)
                  _chartCard(
                    'Request Status Breakdown',
                    SizedBox(
                      height: 240,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: PieChart(PieChartData(
                              sections: [
                                PieChartSectionData(
                                    value: approved.toDouble(),
                                    color: Colors.green,
                                    title: approved > 0
                                        ? '${(approved / total * 100).toStringAsFixed(0)}%'
                                        : '',
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                PieChartSectionData(
                                    value: pending.toDouble(),
                                    color: Colors.orange,
                                    title: pending > 0
                                        ? '${(pending / total * 100).toStringAsFixed(0)}%'
                                        : '',
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                PieChartSectionData(
                                    value: rejected.toDouble(),
                                    color: Colors.red,
                                    title: rejected > 0
                                        ? '${(rejected / total * 100).toStringAsFixed(0)}%'
                                        : '',
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ],
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                            )),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _legendItem('Approved', Colors.green, approved),
                                _legendItem('Pending', Colors.orange, pending),
                                _legendItem('Rejected', Colors.red, rejected),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Top Reasons
                if (topReasons.isNotEmpty)
                  _chartCard(
                    'Top Request Reasons',
                    Column(
                      children: topReasons.entries.map((e) {
                        final pct = total > 0 ? e.value / total : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(e.key,
                                        style: const TextStyle(fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Text('${e.value}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey[200],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Color(0xff060121)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _overallStatCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(
              child: Text('$label ($count)',
                  style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _monthShort(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[m - 1];
  }
}

String _monthShort(int m) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[m - 1];
}

// ─────────────────────────────────────────────
// Individual Student Detail Analytics Screen
// ─────────────────────────────────────────────

class StudentDetailAnalyticsScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentDetailAnalyticsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentDetailAnalyticsScreen> createState() =>
      _StudentDetailAnalyticsScreenState();
}

class _StudentDetailAnalyticsScreenState
    extends State<StudentDetailAnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Compute monthly days for last 6 months from requests
  List<MapEntry<String, int>> _monthlyDays(List<RequestModel> requests) {
    final now = DateTime.now();
    final Map<String, int> map = {};
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      map[_monthShort(m.month)] = 0;
    }
    for (final r in requests) {
      final d = r.createdAt.toDate();
      final diff = (now.year - d.year) * 12 + (now.month - d.month);
      if (diff >= 0 && diff < 6) {
        final key = _monthShort(d.month);
        if (map.containsKey(key)) {
          map[key] = map[key]! + _parseDays(r.leaveDate, r.returnDate);
        }
      }
    }
    return map.entries.toList();
  }

  Map<String, int> _reasonsBreakdown(List<RequestModel> requests) {
    final Map<String, int> map = {};
    for (final r in requests) {
      final key = r.reason.trim().isEmpty ? 'Other' : r.reason.trim();
      final short = key.length > 18 ? '${key.substring(0, 18)}…' : key;
      map[short] = (map[short] ?? 0) + 1;
    }
    return map;
  }

  Color _colorForReason(String reason) {
    final palette = [
      Colors.blue,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.green,
      Colors.pink,
    ];
    return palette[reason.hashCode.abs() % palette.length];
  }

  IconData _iconForReason(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('family')) return Icons.family_restroom;
    if (lower.contains('medical') || lower.contains('health')) {
      return Icons.medical_services;
    }
    if (lower.contains('religious') ||
        lower.contains('church') ||
        lower.contains('mosque')) return Icons.church;
    if (lower.contains('emergency')) return Icons.warning_amber;
    return Icons.help_outline;
  }

  Color _statusColor(String status) {
    if (status == 'approved') return Colors.green;
    if (status == 'rejected') return Colors.red;
    if (status.contains('pending')) return Colors.orange;
    return Colors.grey;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      case 'pending_hod':
      case 'pending_student_affairs':
      case 'pending_warden':
        return 'Pending';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("${widget.studentName}'s Analytics",
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff060121),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('requests')
            .where('studentId', isEqualTo: widget.studentId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final requests =
              docs.map((d) => RequestModel.fromMap(d.data(), d.id)).toList();

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 72, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No exeat history',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('This student has not submitted any exeat requests yet.',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          // Compute stats
          final totalExeats = requests.length;
          final totalDays = requests.fold(
              0, (acc, r) => acc + _parseDays(r.leaveDate, r.returnDate));
          final approved = requests.where((r) => r.status == 'approved').length;
          final avgDays = totalExeats > 0 ? totalDays / totalExeats : 0.0;

          final lastRequest = requests.first;
          final lastDate = lastRequest.createdAt.toDate();
          final daysSinceLast = DateTime.now().difference(lastDate).inDays;
          final lastLabel = daysSinceLast == 0
              ? 'Today'
              : daysSinceLast == 1
                  ? '1 day ago'
                  : '$daysSinceLast days ago';

          final monthly = _monthlyDays(requests);
          final reasons = _reasonsBreakdown(requests);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary cards
                Row(children: [
                  Expanded(
                      child: _statCard(
                          'Total Days',
                          '$totalDays',
                          Icons.calendar_today,
                          Colors.blue,
                          '+$totalDays total')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _statCard('Total Exeats', '$totalExeats',
                          Icons.logout, Colors.green, '$approved approved')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _statCard(
                          'Avg Days/Exeat',
                          avgDays.toStringAsFixed(1),
                          Icons.trending_up,
                          Colors.orange,
                          'per exeat')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _statCard(
                          'Last Exeat',
                          lastLabel,
                          Icons.history,
                          Colors.purple,
                          '${lastDate.day}/${lastDate.month}/${lastDate.year}')),
                ]),

                const SizedBox(height: 20),

                // Monthly Days Trend (Line Chart)
                _chartBox(
                  'Monthly Exeat Days Trend',
                  SizedBox(
                    height: 230,
                    child: monthly.every((e) => e.value == 0)
                        ? const Center(child: Text('No data for recent months'))
                        : Padding(
                            padding: const EdgeInsets.only(right: 16, top: 12),
                            child: LineChart(LineChartData(
                              gridData: const FlGridData(
                                  show: true, drawVerticalLine: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 36,
                                        interval: 1)),
                                bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) {
                                    final i = v.toInt();
                                    if (i >= 0 && i < monthly.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(monthly[i].key,
                                            style:
                                                const TextStyle(fontSize: 11)),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                )),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: monthly
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(e.key.toDouble(),
                                          e.value.value.toDouble()))
                                      .toList(),
                                  isCurved: true,
                                  color: Colors.indigo,
                                  barWidth: 3,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                      show: true,
                                      color: Colors.indigo.withOpacity(0.1)),
                                ),
                              ],
                              minY: 0,
                            )),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Cumulative Bar Chart
                _chartBox(
                  'Cumulative Days Over Time',
                  SizedBox(
                    height: 230,
                    child: monthly.every((e) => e.value == 0)
                        ? const Center(child: Text('No data'))
                        : Padding(
                            padding: const EdgeInsets.only(right: 16, top: 12),
                            child: BarChart(BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              gridData: const FlGridData(
                                  show: true, drawVerticalLine: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 36,
                                        interval: 5)),
                                bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) {
                                    final i = v.toInt();
                                    if (i >= 0 && i < monthly.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(monthly[i].key,
                                            style:
                                                const TextStyle(fontSize: 11)),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                )),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: monthly.asMap().entries.map((e) {
                                int cumulative = monthly
                                    .sublist(0, e.key + 1)
                                    .fold(0, (s, m) => s + m.value);
                                return BarChartGroupData(x: e.key, barRods: [
                                  BarChartRodData(
                                    toY: cumulative.toDouble(),
                                    color: Colors.teal,
                                    width: 20,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(5)),
                                  ),
                                ]);
                              }).toList(),
                              minY: 0,
                            )),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Reasons Pie Chart
                if (reasons.isNotEmpty)
                  _chartBox(
                    'Exeat Reasons Breakdown',
                    SizedBox(
                      height: 260,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: PieChart(PieChartData(
                              sections: reasons.entries.map((e) {
                                final pct = (e.value / totalExeats * 100)
                                    .toStringAsFixed(1);
                                return PieChartSectionData(
                                  value: e.value.toDouble(),
                                  title: '$pct%',
                                  color: _colorForReason(e.key),
                                  radius: 60,
                                  titleStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                );
                              }).toList(),
                              centerSpaceRadius: 45,
                              sectionsSpace: 2,
                            )),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: reasons.entries.map((e) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                            color: _colorForReason(e.key),
                                            borderRadius:
                                                BorderRadius.circular(3)),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(e.key,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w500),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            Text('${e.value}x',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[600])),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Recent History
                _buildRecentHistory(requests),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _chartBox(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildRecentHistory(List<RequestModel> requests) {
    final recent = requests.take(8).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Exeat History',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...recent.map((r) {
            final days = _parseDays(r.leaveDate, r.returnDate);
            final date = r.createdAt.toDate();
            final formattedDate = '${date.day}/${date.month}/${date.year}';
            final color = _statusColor(r.status);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _colorForReason(r.reason).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_iconForReason(r.reason),
                        color: _colorForReason(r.reason), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.reason.trim().isEmpty ? 'No reason' : r.reason,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('$formattedDate  •  To: ${r.destination}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('$days ${days == 1 ? 'day' : 'days'}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700])),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(_statusLabel(r.status),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
