import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/providers/portal_provider.dart';

class AttendanceBodyScreen extends StatelessWidget {
  const AttendanceBodyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final portal = context.watch<PortalProvider>();

    if (portal.attendanceState == PortalLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (portal.attendanceState == PortalLoadState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(portal.attendanceError ?? 'Failed to load attendance.'),
        ),
      );
    }

    if (portal.attendance.isEmpty) {
      return const Center(child: Text('No attendance data available.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: portal.attendance.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = portal.attendance[index];
        final pct = row.percentage;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  row.isSafe ? Colors.green.withValues(alpha: 0.18) : Colors.red.withValues(alpha: 0.18),
              child: Text('${pct.toStringAsFixed(0)}%'),
            ),
            title: Text(row.subjectName),
            subtitle: Text('${row.attended}/${row.conducted} classes attended'),
            trailing: row.isSafe
                ? Text('${row.classesCanSkip} skip', style: const TextStyle(color: Colors.green))
                : Text('${row.classesNeeded} needed', style: const TextStyle(color: Colors.red)),
          ),
        );
      },
    );
  }
}
