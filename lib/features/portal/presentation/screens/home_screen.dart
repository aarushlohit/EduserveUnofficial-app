import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/portal_models.dart';
import '../../domain/providers/portal_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'webview_screen.dart';
import 'attendance_screen.dart';
import 'timetable_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen — student dashboard
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PortalProvider>().fetchAll();
    });
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _DashboardTab(),
          _PortalTab(),
          _AttendanceTab(),
          _TimetableTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.language_outlined),
            activeIcon: Icon(Icons.language),
            label: 'Portal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Timetable',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Tab
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final portal = context.watch<PortalProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduServe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<PortalProvider>().fetchAll(),
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            // ── Student greeting card ────────────────────────────────────
            _StudentCard(session: auth.session),
            const SizedBox(height: 8),

            // ── Today's timetable ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.today, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    "Today's Classes",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            if (portal.timetableState == PortalLoadState.loaded)
              portal.todayTimetable.isEmpty
                  ? const _EmptyHint(text: 'No classes today 🎉')
                  : Column(
                      children: portal.todayTimetable
                          .map((s) => _TodaySlotTile(slot: s))
                          .toList(),
                    )
            else if (portal.timetableState == PortalLoadState.loading)
              const _Shimmer(height: 80)
            else
              const _EmptyHint(text: 'Timetable not loaded yet'),

            const SizedBox(height: 8),

            // ── Attendance summary ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Attendance',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                  if (portal.attendanceState == PortalLoadState.loaded)
                    Text(
                      '${portal.attendance.where((r) => r.isSafe).length}/'
                      '${portal.attendance.length} safe',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                ],
              ),
            ),
            if (portal.attendanceState == PortalLoadState.loaded)
              portal.attendance.isEmpty
                  ? const _EmptyHint(text: 'No attendance data')
                  : Column(
                      children: portal.attendance
                          .map((r) => _AttendanceSummaryTile(record: r))
                          .toList(),
                    )
            else if (portal.attendanceState == PortalLoadState.loading)
              const _Shimmer(height: 120)
            else
              const _EmptyHint(text: 'Attendance not loaded yet'),

            const SizedBox(height: 8),

            // ── Pending assignments ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Pending Assignments',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            if (portal.assignmentState == PortalLoadState.loaded)
              portal.pendingAssignments.isEmpty
                  ? const _EmptyHint(text: 'No pending assignments')
                  : Column(
                      children: portal.pendingAssignments
                          .take(3)
                          .map((a) => _AssignmentTile(assignment: a))
                          .toList(),
                    )
            else if (portal.assignmentState == PortalLoadState.loading)
              const _Shimmer(height: 80)
            else
              const _EmptyHint(text: 'Assignments not loaded yet'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Portal Tab — full WebView
// ─────────────────────────────────────────────────────────────────────────────

class _PortalTab extends StatelessWidget {
  const _PortalTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal'),
        actions: [
          Consumer<PortalProvider>(
            builder: (_, portal, __) => IconButton(
              icon: Icon(
                portal.darkWebMode
                    ? Icons.dark_mode
                    : Icons.light_mode_outlined,
              ),
              tooltip: 'Toggle dark mode for portal',
              onPressed: () => portal.toggleDarkWebMode(),
            ),
          ),
        ],
      ),
      body: const EduServeWebViewBody(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance Tab
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab();

  @override
  Widget build(BuildContext context) {
    return const AttendanceBodyScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timetable Tab
// ─────────────────────────────────────────────────────────────────────────────

class _TimetableTab extends StatelessWidget {
  const _TimetableTab();

  @override
  Widget build(BuildContext context) {
    return const TimetableBodyScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable card: student greeting
// ─────────────────────────────────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.session});
  final dynamic session; // UserSession

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = session.studentName ?? 'Student';
    final roll = session.rollNumber;
    final branch = session.branch;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primary,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (roll != null)
                    Text(
                      roll,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                  if (branch != null)
                    Text(
                      branch,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withAlpha(128),
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
}

// ── Small reusable widgets ─────────────────────────────────────────────────────

class _TodaySlotTile extends StatelessWidget {
  const _TodaySlotTile({required this.slot});
  final TimetableSlot slot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          '${slot.periodNumber}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(slot.subjectName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(
        '${slot.startTime}  –  ${slot.endTime}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: slot.roomNumber != null
          ? Chip(label: Text(slot.roomNumber!, style: const TextStyle(fontSize: 11)))
          : null,
    );
  }
}

class _AttendanceSummaryTile extends StatelessWidget {
  const _AttendanceSummaryTile({required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = record.percentage;
    final color = pct >= 75
        ? Colors.green.shade600
        : pct >= 60
            ? Colors.orange.shade700
            : Color(0xFF38BDF8);

    return ListTile(
      dense: true,
      title: Text(record.subjectName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (pct / 100).clamp(0.0, 1.0),
          minHeight: 5,
          backgroundColor: colorScheme.outline.withAlpha(51),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
      trailing: Text(
        '${pct.toStringAsFixed(1)}%',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.assignment});
  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    final daysLeft = assignment.dueDate.difference(DateTime.now()).inDays;
    final urgentColor =
        daysLeft <= 1 ? const Color(0xFF38BDF8) : (daysLeft <= 3 ? Colors.orange : Colors.green);

    return ListTile(
      dense: true,
      leading: const Icon(Icons.assignment_outlined),
      title: Text(assignment.title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(assignment.subject, style: const TextStyle(fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: urgentColor.withAlpha(26),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: urgentColor.withAlpha(77)),
        ),
        child: Text(
          daysLeft == 0
              ? 'Today'
              : daysLeft == 1
                  ? '1 day'
                  : '$daysLeft days',
          style: TextStyle(fontSize: 11, color: urgentColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant.withAlpha(77),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

