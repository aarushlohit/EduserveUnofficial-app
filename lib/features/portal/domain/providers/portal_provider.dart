import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/portal_models.dart';
import '../../data/portal_scraper.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PortalProvider
// ─────────────────────────────────────────────────────────────────────────────

enum PortalLoadState { idle, loading, loaded, error }

class PortalProvider extends ChangeNotifier {
  final _scraper = PortalScraper.instance;

  // ── State ──────────────────────────────────────────────────────────────────

  PortalLoadState _attendanceState = PortalLoadState.idle;
  PortalLoadState _timetableState = PortalLoadState.idle;
  PortalLoadState _assignmentState = PortalLoadState.idle;

  List<AttendanceRecord> _attendance = [];
  List<TimetableSlot> _timetable = [];
  List<Assignment> _assignments = [];

  String? _attendanceError;
  String? _timetableError;
  String? _assignmentError;

  bool _darkWebMode = false;
  ThemeMode _themeMode = ThemeMode.system;

  // ── Getters ────────────────────────────────────────────────────────────────

  PortalLoadState get attendanceState => _attendanceState;
  PortalLoadState get timetableState => _timetableState;
  PortalLoadState get assignmentState => _assignmentState;

  List<AttendanceRecord> get attendance => _attendance;
  List<TimetableSlot> get timetable => _timetable;
  List<Assignment> get assignments => _assignments;

  String? get attendanceError => _attendanceError;
  String? get timetableError => _timetableError;
  String? get assignmentError => _assignmentError;

  bool get darkWebMode => _darkWebMode;
  ThemeMode get themeMode => _themeMode;

  /// Today's timetable slots.
  List<TimetableSlot> get todayTimetable {
    final dayName = _dayName(DateTime.now().weekday);
    return _timetable
        .where((s) => s.day.toLowerCase() == dayName.toLowerCase())
        .toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
  }

  /// Pending (not yet due) assignments sorted by nearest due date.
  List<Assignment> get pendingAssignments => _assignments
      .where((a) => !a.isOverdue)
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  // ── Load preferences ───────────────────────────────────────────────────────

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _darkWebMode =
        prefs.getBool(AppConstants.prefDarkWebMode) ?? false;
    final modeIndex =
        prefs.getInt(AppConstants.prefThemeMode) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[modeIndex];

    // Restore cached timetable (offline support)
    final cachedTimetable = prefs.getString('_cached_timetable');
    if (cachedTimetable != null) {
      _timetable = _decodeTimetableCache(cachedTimetable);
    }

    notifyListeners();
  }

  // ── Toggle settings ────────────────────────────────────────────────────────

  Future<void> toggleDarkWebMode() async {
    _darkWebMode = !_darkWebMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefDarkWebMode, _darkWebMode);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefThemeMode, mode.index);
    notifyListeners();
  }

  // ── Fetch attendance ───────────────────────────────────────────────────────

  Future<void> fetchAttendance() async {
    _attendanceState = PortalLoadState.loading;
    _attendanceError = null;
    notifyListeners();

    try {
      _attendance = await _scraper.fetchAttendance();
      _attendanceState = PortalLoadState.loaded;
      _checkLowAttendanceAlerts();
    } catch (e) {
      _attendanceError = e.toString();
      _attendanceState = PortalLoadState.error;
    }
    notifyListeners();
  }

  void _checkLowAttendanceAlerts() {
    for (final record in _attendance) {
      if (!record.isSafe) {
        NotificationService.instance.showLowAttendanceAlert(
          record.subjectName,
          record.percentage,
        );
      }
    }
  }

  // ── Fetch timetable ────────────────────────────────────────────────────────

  Future<void> fetchTimetable() async {
    _timetableState = PortalLoadState.loading;
    _timetableError = null;
    notifyListeners();

    try {
      _timetable = await _scraper.fetchTimetable();
      _timetableState = PortalLoadState.loaded;
      await _cacheTimetable();
    } catch (e) {
      _timetableError = e.toString();
      _timetableState = PortalLoadState.error;
    }
    notifyListeners();
  }

  Future<void> _cacheTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _timetable
        .map((s) => {
              'day': s.day,
              'period': s.periodNumber,
              'start': s.startTime,
              'end': s.endTime,
              'subject': s.subjectName,
              'code': s.subjectCode,
              'faculty': s.facultyName,
              'room': s.roomNumber,
            })
        .toList();
    await prefs.setString('_cached_timetable', jsonEncode(data));
  }

  List<TimetableSlot> _decodeTimetableCache(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((entry) {
        final m = entry as Map<String, dynamic>;
        return TimetableSlot(
          day: m['day'] as String,
          periodNumber: (m['period'] as num).toInt(),
          startTime: m['start'] as String,
          endTime: m['end'] as String,
          subjectName: m['subject'] as String,
          subjectCode: m['code'] as String?,
          facultyName: m['faculty'] as String?,
          roomNumber: m['room'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Fetch assignments ──────────────────────────────────────────────────────

  Future<void> fetchAssignments() async {
    _assignmentState = PortalLoadState.loading;
    _assignmentError = null;
    notifyListeners();

    try {
      _assignments = await _scraper.fetchAssignments();
      _assignmentState = PortalLoadState.loaded;
      _scheduleAssignmentReminders();
    } catch (e) {
      _assignmentError = e.toString();
      _assignmentState = PortalLoadState.error;
    }
    notifyListeners();
  }

  void _scheduleAssignmentReminders() {
    for (final a in _assignments) {
      if (!a.isOverdue) {
        NotificationService.instance.scheduleAssignmentReminder(
          id: a.hashCode,
          subject: a.subject,
          dueDate: a.dueDate,
        );
      }
    }
  }

  // ── Fetch all ──────────────────────────────────────────────────────────────

  Future<void> fetchAll() => Future.wait([
        fetchAttendance(),
        fetchTimetable(),
        fetchAssignments(),
      ]);

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _dayName(int weekday) {
    const days = [
      '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday'
    ];
    return weekday < days.length ? days[weekday] : '';
  }
}
