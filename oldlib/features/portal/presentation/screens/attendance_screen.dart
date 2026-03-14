import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/portal_models.dart';
import '../providers/portal_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AttendanceBodyScreen
// ─────────────────────────────────────────────────────────────────────────────

class AttendanceBodyScreen extends StatelessWidget {
  const AttendanceBodyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<PortalProvider>().fetchAttendance(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<PortalProvider>(
        builder: (context, portal, _) {
          if (portal.attendanceState == PortalLoadState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (portal.attendanceState == PortalLoadState.error) {
            return _ErrorView(
              message: portal.attendanceError ?? 'Unknown error',
              onRetry: () => portal.fetchAttendance(),
            );
          }

          if (portal.attendance.isEmpty) {
            return const _EmptyView(message: 'No attendance data found.');
          }

          return _AttendanceList(records: portal.attendance);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance list
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceList extends StatelessWidget {
  const _AttendanceList({required this.records});
  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final safe = records.where((r) => r.isSafe).length;
    final total = records.length;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        // ── Summary chip row ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _SummaryChip(
                label: '$safe / $total Safe',
                color: Colors.green.shade600,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: '${total - safe} At Risk',
                color: Colors.red.shade600,
                icon: Icons.warning_amber_outlined,
              ),
            ],
          ),
        ),
        const Divider(height: 16),

        // ── Per-subject cards ─────────────────────────────────────────────
        ...records.map((r) => _AttendanceCard(record: r)),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = record.percentage;
    final color = pct >= 75
        ? Colors.green.shade600
        : pct >= 60
            ? Colors.orange.shade700
            : Colors.red.shade600;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject name + code row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.subjectName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (record.subjectCode.isNotEmpty)
                        Text(
                          record.subjectCode,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withAlpha(77)),
                  ),
                  child: Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: colorScheme.outline.withAlpha(51),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${record.attended} / ${record.conducted} classes',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withAlpha(153),
                  ),
                ),
                if (record.isSafe)
                  Text(
                    'Can skip ${record.classesCanSkip} more',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  )
                else
                  Text(
                    'Need ${record.classesNeeded} to reach 75%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade600,
                    ),
                  ),
              ],
            ),

            if (record.facultyName != null && record.facultyName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Faculty: ${record.facultyName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withAlpha(128),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.color,
    required this.icon,
  });
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load attendance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
