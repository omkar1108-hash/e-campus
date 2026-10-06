/// Roles used for Role-Based Access Control (RBAC).
enum UserRole {
  student('Student'),
  classRep('Class Representative'),
  teacher('Teacher'),
  admin('Administrator');

  const UserRole(this.label);
  final String label;

  static UserRole fromName(String? name) => UserRole.values.firstWhere(
    (r) => r.name == name,
    orElse: () => UserRole.student,
  );
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.phone,
    required this.name,
    required this.department,
    required this.role,
  });

  final String uid;
  final String phone;
  final String name;
  final String department;
  final UserRole role;

  AppUser copyWith({String? name, String? department, UserRole? role}) =>
      AppUser(
        uid: uid,
        phone: phone,
        name: name ?? this.name,
        department: department ?? this.department,
        role: role ?? this.role,
      );

  Map<String, dynamic> toMap() => {
    'phone': phone,
    'name': name,
    'department': department,
    'role': role.name,
  };

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
    uid: uid,
    phone: (map['phone'] ?? '') as String,
    name: (map['name'] ?? '') as String,
    department: (map['department'] ?? '') as String,
    role: UserRole.fromName(map['role'] as String?),
  );
}
