// ─────────────────────────────────────────────────────────────────────────────
// UserSession — immutable value object
// ─────────────────────────────────────────────────────────────────────────────

class UserSession {
  const UserSession({
    required this.isAuthenticated,
    required this.lastLoginAt,
    this.studentName,
    this.rollNumber,
    this.branch,
    this.semester,
    this.profileImageUrl,
  });

  final bool isAuthenticated;
  final DateTime lastLoginAt;
  final String? studentName;
  final String? rollNumber;
  final String? branch;
  final String? semester;
  final String? profileImageUrl;

  static UserSession get empty => UserSession(
        isAuthenticated: false,
        lastLoginAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  UserSession copyWith({
    bool? isAuthenticated,
    DateTime? lastLoginAt,
    String? studentName,
    String? rollNumber,
    String? branch,
    String? semester,
    String? profileImageUrl,
  }) {
    return UserSession(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      studentName: studentName ?? this.studentName,
      rollNumber: rollNumber ?? this.rollNumber,
      branch: branch ?? this.branch,
      semester: semester ?? this.semester,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
