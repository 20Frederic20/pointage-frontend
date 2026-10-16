import '../../core/role.dart';

/// Compte utilisateur (`UserResponse`), proposé à la création d'un employé.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.isActive,
    this.firstName,
    this.lastName,
  });

  final String id;
  final String email;
  final Role role;
  final bool isActive;
  final String? firstName;
  final String? lastName;

  /// « Prénom Nom — email », ou l'email seul quand le nom est vide.
  String get displayName {
    final name = [firstName, lastName].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');
    return name.isEmpty ? email : '$name — $email';
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        role: Role.fromWire(j['role'] as String),
        isActive: j['isActive'] as bool,
        firstName: j['firstName'] as String?,
        lastName: j['lastName'] as String?,
      );
}
