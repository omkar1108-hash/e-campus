/// Roles used for Role-Based Access Control (RBAC).
enum UserRole {
  student('Student'),
  classRep('Class Representative'),
  teacher('Teacher'),
  hod('Head of Department'),
  libraryStaff('Library Staff'),
  busDriver('Bus Driver'),
  adminStaff('Admin Staff'),
  grievanceCommittee('Grievance Committee'),
  admin('Administrator');

  const UserRole(this.label);
  final String label;

  /// Teachers and heads of department teach classes, mark attendance and
  /// share assignments.
  bool get isTeaching => this == teacher || this == hod;

  static UserRole fromName(String? name) => UserRole.values.firstWhere(
    (r) => r.name == name,
    orElse: () => UserRole.student,
  );
}

enum Gender {
  male('Male'),
  female('Female');

  const Gender(this.label);
  final String label;

  static Gender? fromName(String? name) {
    for (final g in Gender.values) {
      if (g.name == name) return g;
    }
    return null;
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.department,
    required this.role,
    this.gender,
    this.active = true,
  });

  final String uid;
  final String email;
  final String name;
  final String department;
  final UserRole role;

  /// Needed for students so teachers can balance class representatives.
  final Gender? gender;

  /// False once an administrator has disabled the account.
  final bool active;

  AppUser copyWith({
    String? name,
    String? department,
    UserRole? role,
    Gender? gender,
    bool? active,
  }) => AppUser(
    uid: uid,
    email: email,
    name: name ?? this.name,
    department: department ?? this.department,
    role: role ?? this.role,
    gender: gender ?? this.gender,
    active: active ?? this.active,
  );

  Map<String, dynamic> toMap() => {
    'email': email,
    'name': name,
    'department': department,
    'role': role.name,
    if (gender != null) 'gender': gender!.name,
    'active': active,
  };

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
    uid: uid,
    email: (map['email'] ?? '') as String,
    name: (map['name'] ?? '') as String,
    department: (map['department'] ?? '') as String,
    role: UserRole.fromName(map['role'] as String?),
    gender: Gender.fromName(map['gender'] as String?),
    // Profiles created before this field existed are active.
    active: (map['active'] ?? true) as bool,
  );
}
