DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

/// Anomalie (`GET /anomalies`). Les champs du pointage peuvent manquer sur les anciennes anomalies.
class Anomaly {
  const Anomaly({
    required this.id,
    required this.type,
    required this.severity,
    required this.status,
    this.detectedAt,
    this.employeeId,
    this.employeeNumber,
    this.employeeFirstName,
    this.employeeLastName,
    this.assistedByFirstName,
    this.assistedByLastName,
    this.occuredAt,
    this.entryType,
    this.hasPhoto = false,
    this.decidedAt,
    this.decisionComment,
    this.siteName,
  });

  final String id;
  final String type;
  final String severity;
  final String status;
  final DateTime? detectedAt;
  final String? employeeId;
  final String? employeeNumber;
  final String? employeeFirstName;
  final String? employeeLastName;
  final String? assistedByFirstName;
  final String? assistedByLastName;
  final DateTime? occuredAt;
  final String? entryType;
  final bool hasPhoto;
  final DateTime? decidedAt;
  final String? decisionComment;

  /// Site de l'employé pointé à la date du pointage ; null s'il n'est pas connu.
  final String? siteName;

  bool get isOpen => status == 'OPEN';

  String get employeeName => _name(employeeFirstName, employeeLastName);
  String get assistedByName => _name(assistedByFirstName, assistedByLastName);

  static String _name(String? first, String? last) => [first, last].whereType<String>().join(' ').trim();

  factory Anomaly.fromJson(Map<String, dynamic> j) => Anomaly(
        id: j['id'] as String,
        type: j['type'] as String,
        severity: (j['severity'] as String?) ?? '',
        status: j['status'] as String,
        detectedAt: _date(j['detectedAt']),
        employeeId: j['employeeId'] as String?,
        employeeNumber: j['employeeNumber'] as String?,
        employeeFirstName: j['employeeFirstName'] as String?,
        employeeLastName: j['employeeLastName'] as String?,
        assistedByFirstName: j['assistedByFirstName'] as String?,
        assistedByLastName: j['assistedByLastName'] as String?,
        occuredAt: _date(j['occuredAt']),
        entryType: j['entryType'] as String?,
        hasPhoto: (j['hasPhoto'] as bool?) ?? false,
        decidedAt: _date(j['decidedAt']),
        decisionComment: j['decisionComment'] as String?,
        siteName: j['siteName'] as String?,
      );
}

/// Libellé français d'un statut.
String anomalyStatusLabel(String status) => switch (status) {
      'OPEN' => 'À traiter',
      'IN_PROGRESS' => 'En cours',
      'RESOLVED' => 'Résolue',
      'CANCELLED' => 'Annulée',
      'VALIDATED' => 'Validée',
      'REJECTED' => 'Rejetée',
      _ => status,
    };

String anomalyEntryTypeLabel(String? t) => switch (t) {
      'IN' => 'Entrée',
      'OUT' => 'Sortie',
      _ => '—',
    };
