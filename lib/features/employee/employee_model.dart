import '../../core/role.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

/// Date seule (`AAAA-MM-JJ`), telle que le backend l'attend et la renvoie.
DateTime? _day(Object? v) => v == null ? null : DateTime.parse(v as String);

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Fiche employé (`EmployeeResponse`) : une par entreprise pour une même personne.
/// Le nom vient du compte, l'entreprise et le site actuel sont calculés par le backend.
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
    this.firstName,
    this.lastName,
    this.companyDirectoryId,
    this.companyName,
    this.currentSiteId,
    this.currentSiteName,
    this.currentAssignmentEndDate,
    this.accountReused = false,
  });

  final String id;
  final String userId;
  final String employeeNumber;
  final Role role;
  final bool isActive;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? firstName;
  final String? lastName;
  final String? companyDirectoryId;
  final String? companyName;
  final String? currentSiteId;
  final String? currentSiteName;
  final DateTime? currentAssignmentEndDate;

  /// Réponse de création seulement : l'email avait déjà un compte, une fiche y a été ajoutée.
  final bool accountReused;

  /// « Prénom Nom », ou le matricule quand le compte n'a pas de nom.
  String get displayName {
    final name = [?firstName, ?lastName].where((p) => p.trim().isNotEmpty).join(' ');
    return name.isEmpty ? employeeNumber : name;
  }

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        userId: j['userId'] as String,
        employeeNumber: j['employeeNumber'] as String,
        role: Role.fromWire(j['role'] as String),
        isActive: j['isActive'] as bool,
        phone: j['phone'] as String?,
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        firstName: j['firstName'] as String?,
        lastName: j['lastName'] as String?,
        companyDirectoryId: j['companyDirectoryId'] as String?,
        companyName: j['companyName'] as String?,
        currentSiteId: j['currentSiteId'] as String?,
        currentSiteName: j['currentSiteName'] as String?,
        currentAssignmentEndDate: _day(j['currentAssignmentEndDate']),
        accountReused: j['accountReused'] as bool? ?? false,
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

/// Données du formulaire de création (`POST /employees/onboard`) : le compte et l'employé
/// sont créés ensemble par le backend, ou pas du tout.
class EmployeeDraft {
  const EmployeeDraft({
    required this.email,
    this.password,
    this.firstName,
    this.lastName,
    required this.directoryId,
    required this.employeeNumber,
    this.role = Role.employee,
    this.phone,
    this.isActive = true,
    this.siteId,
    this.assignmentStartDate,
  });

  final String email;

  /// null ou vide = connexion par code reçu par email.
  final String? password;
  final String? firstName;
  final String? lastName;
  final String directoryId;
  final String employeeNumber;
  final Role role;
  final String? phone;
  final bool isActive;

  /// null = site principal de l'annuaire.
  final String? siteId;

  /// null = aujourd'hui (décidé par le backend).
  final DateTime? assignmentStartDate;

  /// En snake_case : `OnboardEmployeeRequest` n'accepte pas le camelCase.
  Map<String, dynamic> toJson() => {
        'email': email,
        if (password != null && password!.isNotEmpty) 'password': password,
        if (firstName != null && firstName!.isNotEmpty) 'first_name': firstName,
        if (lastName != null && lastName!.isNotEmpty) 'last_name': lastName,
        'directory_id': directoryId,
        'employee_number': employeeNumber,
        'role': role.wire,
        'is_active': isActive,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (siteId != null) 'site_id': siteId,
        if (assignmentStartDate != null) 'assignment_start_date': isoDate(assignmentStartDate!),
      };
}
