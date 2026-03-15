import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/providers/portal_provider.dart';

class TimetableBodyScreen extends StatelessWidget {
  const TimetableBodyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final portal = context.watch<PortalProvider>();

    if (portal.timetableState == PortalLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (portal.timetableState == PortalLoadState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(portal.timetableError ?? 'Failed to load timetable.'),
        ),
      );
    }

    final list = portal.timetable;
    if (list.isEmpty) {
      return const Center(child: Text('No timetable data available.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final slot = list[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${slot.periodNumber}')),
            title: Text(slot.subjectName),
            subtitle: Text('${slot.day}  ${slot.startTime}-${slot.endTime}'),
            trailing: slot.roomNumber == null || slot.roomNumber!.isEmpty
                ? null
                : Text(slot.roomNumber!),
          ),
        );
      },
    );
  }
}
