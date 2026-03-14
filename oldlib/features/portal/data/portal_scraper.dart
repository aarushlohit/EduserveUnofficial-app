import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../domain/portal_models.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/cookie_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PortalScraper
//
// Makes authenticated HTTP requests to the EduServe portal and parses the
// HTML responses to extract structured data.
//
// ── REVERSE ENGINEERING GUIDE ─────────────────────────────────────────────────
//
// Step 1 — Inspect Network Requests in Chrome DevTools
//   1. Open https://eduserve.karunya.edu in Chrome and log in.
//   2. Press F12 → Network tab → check "Preserve log".
//   3. Navigate to Attendance/Timetable pages.
//   4. Look for XHR/Fetch requests or full-page GET requests.
//   5. Click a request → Headers tab → copy the Cookie header value.
//   6. In the Response tab you can see the raw HTML to identify element IDs.
//
// Step 2 — Detect Session Cookies
//   1. After login, F12 → Application tab → Cookies → eduserve.karunya.edu.
//   2. Look for cookies named ASP.NET_SessionId, .ASPXAUTH, or similar.
//   3. These are the cookies this app captures and persists.
//
// Step 3 — Replicate Requests in Flutter (using the http package)
//   final response = await http.get(
//     Uri.parse('https://eduserve.karunya.edu/Student/Attendance'),
//     headers: {'Cookie': '<paste-cookie-string-here>'},
//   );
//   print(response.body); // inspect the HTML
//
// Step 4 — Find CSS selectors for data tables
//   1. In Chrome → Elements tab, right-click a table row → Inspect.
//   2. Note the table id, class, or parent div id.
//   3. Update the querySelector calls in this file accordingly.
//
// ─────────────────────────────────────────────────────────────────────────────

class PortalScraper {
  PortalScraper._();
  static final PortalScraper instance = PortalScraper._();

  // ── HTTP helper ────────────────────────────────────────────────────────────

  Future<http.Response> _get(String url) async {
    final cookieHeader = await CookieService.instance.buildCookieHeader();
    return http
        .get(
          Uri.parse(url),
          headers: {
            'Cookie': cookieHeader,
            'User-Agent': AppConstants.desktopUserAgent,
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        )
        .timeout(const Duration(seconds: 15));
  }

  // ── Attendance ─────────────────────────────────────────────────────────────

  /// Scrape the Attendance page and return a list of [AttendanceRecord].
  ///
  /// ⚠ Selector notes
  /// ─────────────────
  /// Default selectors target a Bootstrap-style table with alternating rows.
  /// If the portal HTML changes, update the querySelector patterns below.
  /// Run `print(response.body)` to inspect the raw HTML during debugging.
  Future<List<AttendanceRecord>> fetchAttendance() async {
    final response = await _get(AppConstants.attendanceUrl);
    if (response.statusCode != 200) {
      throw Exception(
          'Attendance page returned ${response.statusCode}');
    }
    return _parseAttendance(response.body);
  }

  List<AttendanceRecord> _parseAttendance(String html) {
    final doc = html_parser.parse(html);
    final records = <AttendanceRecord>[];

    // ── Try multiple table selector strategies ──────────────────────────────
    // Strategy 1: table with id containing "Attendance"
    dom.Element? table = doc.querySelector('table[id*="Attendance"]') ??
        doc.querySelector('table[id*="attendance"]') ??
        doc.querySelector('.attendance-table') ??
        _findLargestTable(doc);

    if (table == null) return records;

    final rows = table.querySelectorAll('tr');
    // Skip header row(s)
    for (int i = 1; i < rows.length; i++) {
      final cells = rows[i].querySelectorAll('td');
      if (cells.length < 4) continue;

      try {
        // ── Column order may differ — adjust indices as needed ──
        // Typical EduServe layout:
        // [0] S.No  [1] Subject Code  [2] Subject Name
        // [3] Attended  [4] Conducted  [5] Percentage  [6] Faculty
        final code = _clean(cells.length > 1 ? cells[1].text : '');
        final name = _clean(cells.length > 2 ? cells[2].text : code);
        final attended =
            int.tryParse(_clean(cells.length > 3 ? cells[3].text : '0')) ??
                0;
        final conducted =
            int.tryParse(_clean(cells.length > 4 ? cells[4].text : '0')) ??
                0;
        final faculty =
            cells.length > 6 ? _clean(cells[6].text) : null;

        if (code.isEmpty && name.isEmpty) continue;

        records.add(AttendanceRecord(
          subjectCode: code,
          subjectName: name,
          attended: attended,
          conducted: conducted,
          facultyName: faculty?.isEmpty == true ? null : faculty,
        ));
      } catch (_) {
        continue;
      }
    }
    return records;
  }

  // ── Timetable ──────────────────────────────────────────────────────────────

  Future<List<TimetableSlot>> fetchTimetable() async {
    final response = await _get(AppConstants.timetableUrl);
    if (response.statusCode != 200) {
      throw Exception('Timetable page returned ${response.statusCode}');
    }
    return _parseTimetable(response.body);
  }

  List<TimetableSlot> _parseTimetable(String html) {
    final doc = html_parser.parse(html);
    final slots = <TimetableSlot>[];

    // Typical timetable layout: one table per week, rows = days, cols = periods.
    // Adjust selectors below once you've inspected the actual HTML.
    final table = doc.querySelector('table[id*="TimeTable"]') ??
        doc.querySelector('table[id*="timetable"]') ??
        doc.querySelector('.timetable') ??
        _findLargestTable(doc);

    if (table == null) return slots;

    final rows = table.querySelectorAll('tr');
    // Row 0 = header with time slots
    final headers =
        rows.isNotEmpty ? rows[0].querySelectorAll('th, td') : <dom.Element>[];
    final times = headers
        .skip(1)
        .map((h) => _clean(h.text))
        .toList(); // e.g. ["8:30-9:20", "9:20-10:10", ...]

    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
        'Saturday'];

    for (int r = 1; r < rows.length; r++) {
      final cells = rows[r].querySelectorAll('td');
      if (cells.isEmpty) continue;
      final day = days[(r - 1) % days.length];

      for (int c = 1; c < cells.length; c++) {
        final subjectText = _clean(cells[c].text);
        if (subjectText.isEmpty || subjectText == '-') continue;

        String start = '';
        String end = '';
        if (c - 1 < times.length) {
          final parts = times[c - 1].split('-');
          start = parts.isNotEmpty ? parts[0].trim() : '';
          end = parts.length > 1 ? parts[1].trim() : '';
        }

        slots.add(TimetableSlot(
          day: day,
          periodNumber: c,
          startTime: start,
          endTime: end,
          subjectName: subjectText,
        ));
      }
    }
    return slots;
  }

  // ── Assignments ────────────────────────────────────────────────────────────

  Future<List<Assignment>> fetchAssignments() async {
    final response = await _get(AppConstants.assignmentUrl);
    if (response.statusCode != 200) {
      throw Exception('Assignments page returned ${response.statusCode}');
    }
    return _parseAssignments(response.body);
  }

  List<Assignment> _parseAssignments(String html) {
    final doc = html_parser.parse(html);
    final assignments = <Assignment>[];

    final table = doc.querySelector('table[id*="Assignment"]') ??
        doc.querySelector('table[id*="assignment"]') ??
        _findLargestTable(doc);

    if (table == null) return assignments;

    final rows = table.querySelectorAll('tr');
    for (int i = 1; i < rows.length; i++) {
      final cells = rows[i].querySelectorAll('td');
      if (cells.length < 3) continue;
      try {
        final subject = _clean(cells[0].text);
        final title = _clean(cells[1].text);
        final dateText = _clean(cells[2].text);
        final dueDate = _parseDate(dateText) ?? DateTime.now();

        assignments.add(Assignment(
          subject: subject,
          title: title,
          dueDate: dueDate,
        ));
      } catch (_) {
        continue;
      }
    }
    return assignments;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Return the table with the most rows — a heuristic for finding the data
  /// table on pages that don't use IDs.
  dom.Element? _findLargestTable(dom.Document doc) {
    final tables = doc.querySelectorAll('table');
    if (tables.isEmpty) return null;
    return tables.reduce((a, b) =>
        a.querySelectorAll('tr').length >= b.querySelectorAll('tr').length
            ? a
            : b);
  }

  String _clean(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Try common Indian date formats: dd/MM/yyyy, dd-MM-yyyy, MM/dd/yyyy.
  DateTime? _parseDate(String text) {
    final clean = _clean(text);
    final patterns = [
      RegExp(r'^(\d{2})[/\-](\d{2})[/\-](\d{4})$'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(clean);
      if (m != null) {
        final a = int.parse(m.group(1)!);
        final b = int.parse(m.group(2)!);
        final y = int.parse(m.group(3)!);
        // If first part is > 12 it must be a day.
        if (a > 12) return DateTime(y, b, a);
        return DateTime(y, a, b);
      }
    }
    return DateTime.tryParse(clean);
  }
}
