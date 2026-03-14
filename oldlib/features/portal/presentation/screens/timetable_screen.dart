import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/portal_models.dart';
import '../providers/portal_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TimetableBodyScreen
// ─────────────────────────────────────────────────────────────────────────────

class TimetableBodyScreen extends StatefulWidget {
  const TimetableBodyScreen({super.key});

  @override
  State<TimetableBodyScreen> createState() => _TimetableBodyScreenState();
}

class _TimetableBodyScreenState extends State<TimetableBodyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _days = const [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    // Jump to today's tab.
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 5);
    _tabController = TabController(
      length: _days.length,
      vsync: this,
      initialIndex: todayIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<PortalProvider>().fetchTimetable(),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _days.map((d) => Tab(text: d.substring(0, 3))).toList(),
        ),
      ),
      body: Consumer<PortalProvider>(
        builder: (context, portal, _) {
          if (portal.timetableState == PortalLoadState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (portal.timetableState == PortalLoadState.error) {
            return _ErrorView(
              message: portal.timetableError ?? 'Unknown error',
              onRetry: () => portal.fetchTimetable(),
            );
          }

          if (portal.timetable.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No timetable data.',
                      style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    'It may be available on the portal,\n'
                    'or the selectors need updating.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: _days
                .map((day) => _DaySchedule(
                      day: day,
                      slots: portal.timetable
                          .where((s) =>
                              s.day.toLowerCase() == day.toLowerCase())
                          .toList()
                        ..sort((a, b) =>
                            a.periodNumber.compareTo(b.periodNumber)),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One day's schedule
// ─────────────────────────────────────────────────────────────────────────────

class _DaySchedule extends StatelessWidget {
  const _DaySchedule({required this.day, required this.slots});
  final String day;
  final List<TimetableSlot> slots;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.free_breakfast_outlined,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('No classes on $day',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: slots.length,
      itemBuilder: (context, index) => _SlotCard(slot: slots[index]),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot});
  final TimetableSlot slot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Assign a colour per period number so the schedule looks lively.
    final colours = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final colour = colours[slot.periodNumber % colours.length];

    return Card(
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Coloured left accent
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: colour,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Period number circle
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: colour.withAlpha(26),
                      child: Text(
                        '${slot.periodNumber}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colour,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.subjectName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (slot.subjectCode != null)
                            Text(
                              slot.subjectCode!,
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    colorScheme.onSurface.withAlpha(153),
                              ),
                            ),
                          if (slot.facultyName != null)
                            Text(
                              slot.facultyName!,
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    colorScheme.onSurface.withAlpha(128),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (slot.startTime.isNotEmpty)
                          Text(
                            slot.startTime,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (slot.endTime.isNotEmpty)
                          Text(
                            slot.endTime,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                        if (slot.roomNumber != null)
                          Chip(
                            label: Text(slot.roomNumber!,
                                style: const TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
            Text('Failed to load timetable',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
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
