// ─────────────────────────────────────────────────────────────────────────────
// Portal domain models
// ─────────────────────────────────────────────────────────────────────────────

/// One subject's attendance record.
class AttendanceRecord {
  const AttendanceRecord({
    required this.subjectCode,
    required this.subjectName,
    required this.attended,
    required this.conducted,
    this.facultyName,
  });

  final String subjectCode;
  final String subjectName;
  final int attended;
  final int conducted;
  final String? facultyName;

  double get percentage =>
      conducted == 0 ? 0 : (attended / conducted) * 100;

  bool get isSafe => percentage >= 75;

  /// Classes you can miss without going below 75 %.
  int get classesCanSkip {
    if (!isSafe) return 0;
    // attended / (conducted + x) >= 0.75  →  x <= (attended - 0.75*conducted) / 0.75
    return ((attended - 0.75 * conducted) / 0.75).floor().clamp(0, 999);
  }

  /// Classes needed to reach 75 % from below 75 %.
  int get classesNeeded {
    if (isSafe) return 0;
    // (attended + x) / (conducted + x) >= 0.75  →  x >= 3*conducted - 4*attended
    return (3 * conducted - 4 * attended).clamp(0, 999);
  }

  @override
  String toString() =>
      '$subjectCode: $attended/$conducted (${percentage.toStringAsFixed(1)}%)';
}

/// A single period slot in the timetable.
class TimetableSlot {
  const TimetableSlot({
    required this.day,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    this.subjectCode,
    this.facultyName,
    this.roomNumber,
  });

  final String day;
  final int periodNumber;
  final String startTime;
  final String endTime;
  final String subjectName;
  final String? subjectCode;
  final String? facultyName;
  final String? roomNumber;
}

/// One assignment entry.
class Assignment {
  const Assignment({
    required this.subject,
    required this.title,
    required this.dueDate,
    this.description,
    this.status = AssignmentStatus.pending,
  });

  final String subject;
  final String title;
  final DateTime dueDate;
  final String? description;
  final AssignmentStatus status;

  bool get isOverdue => dueDate.isBefore(DateTime.now());
}

enum AssignmentStatus { pending, submitted, overdue }
