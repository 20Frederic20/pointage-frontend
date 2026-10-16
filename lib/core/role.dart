/// Rôles du backend (`RoleSchema`), du moins au plus élevé.
enum Role {
  employee('EMPLOYEE', 'Employé'),
  manager('MANAGER', 'Manager'),
  hr('HR', 'RH'),
  payroll('PAYROLL', 'Paie'),
  admin('ADMIN', 'Admin');

  const Role(this.wire, this.label);

  /// Valeur échangée avec l'API.
  final String wire;
  final String label;

  static Role fromWire(String value) =>
      values.firstWhere((r) => r.wire == value, orElse: () => throw FormatException('Rôle inconnu : $value'));
}
