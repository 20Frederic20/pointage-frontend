import '../../core/role.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Fiche employé (`EmployeeResponse`). Le lien vers l'annuaire passe par les
/// affectations côté backend : il n'est pas sur l'employé.
class Employee {
  const Employee({
    required this.id,
    required this.userId,
    required this.employeeNumber,
    required this.role,
    required this.isActive,
    this.phone,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String employeeNumber;
  final Role role;
  final bool isActive;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        userId: j['userId'] as String,
        employeeNumber: j['employeeNumber'] as String,
        role: Role.fromWire(j['role'] as String),
        isActive: j['isActive'] as bool,
        phone: j['phone'] as String?,
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
      );
}

/// Critères de la liste. [search] est un matricule exact (le backend ne fait pas de recherche partielle).
class EmployeeFilters {
  const EmployeeFilters({this.search = '', this.role, this.isActive});

  final String search;
  final Role? role;
  final bool? isActive;

  bool get isEmpty => search.isEmpty && role == null && isActive == null;
}

/// Données du formulaire de création (`POST /employees`).
class EmployeeDraft {
  const EmployeeDraft({
    required this.userId,
    required this.directoryId,
    required this.employeeNumber,
    this.role = Role.employee,
    this.phone,
    this.isActive = false,
    this.siteId,
    this.assignmentStartDate,
  });

  final String userId;
  final String directoryId;
  final String employeeNumber;
  final Role role;
  final String? phone;
  final bool isActive;

  /// null = site principal de l'annuaire.
  final String? siteId;

  /// null = aujourd'hui (décidé par le backend).
  final DateTime? assignmentStartDate;

  /// En snake_case : `CreateEmployeeRequest` n'accepte pas le camelCase.
  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'directory_id': directoryId,
        'employee_number': employeeNumber,
        'role': role.wire,
        'is_active': isActive,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (siteId != null) 'site_id': siteId,
        if (assignmentStartDate != null) 'assignment_start_date': _isoDate(assignmentStartDate!),
      };
}
