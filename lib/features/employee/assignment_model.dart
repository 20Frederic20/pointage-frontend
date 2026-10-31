/// Affectation (`EmployeeAssignmentResponse`) : où un employé travaille, et de quand à quand.
class Assignment {
  const Assignment({
    required this.id,
    required this.directoryId,
    required this.siteId,
    required this.startDate,
    this.directoryName,
    this.siteName,
    this.endDate,
  });

  final String id;
  final String directoryId;
  final String? directoryName;
  final String siteId;
  final String? siteName;
  final DateTime startDate;

  /// Dernier jour inclus ; null = sans fin.
  final DateTime? endDate;

  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
        id: j['id'] as String,
        directoryId: j['directoryId'] as String,
        directoryName: j['directoryName'] as String?,
        siteId: j['siteId'] as String,
        siteName: j['siteName'] as String?,
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: j['endDate'] == null ? null : DateTime.parse(j['endDate'] as String),
      );
}
