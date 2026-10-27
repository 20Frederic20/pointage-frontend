import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/anomaly/anomaly_model.dart';

void main() {
  test('parses a full item', () {
    final a = Anomaly.fromJson({
      'id': 'a1', 'type': 'ASSISTED_POINTING', 'severity': 'BLOCKING', 'status': 'OPEN',
      'detectedAt': '2026-10-27T08:05:00Z', 'employeeId': 'e1', 'employeeNumber': 'EMP0000001',
      'employeeFirstName': 'Ana', 'employeeLastName': 'Dossou',
      'assistedByFirstName': 'Paul', 'assistedByLastName': 'Kpade',
      'occuredAt': '2026-10-27T08:05:00Z', 'entryType': 'IN', 'hasPhoto': true,
      'decidedAt': null, 'decisionComment': null, 'siteName': 'Siège Cotonou',
    });
    expect((a.id, a.status, a.isOpen, a.hasPhoto, a.entryType), ('a1', 'OPEN', true, true, 'IN'));
    expect((a.employeeName, a.assistedByName, a.employeeNumber), ('Ana Dossou', 'Paul Kpade', 'EMP0000001'));
    expect(a.occuredAt, isNotNull);
    expect(a.decidedAt, isNull);
    expect(a.siteName, 'Siège Cotonou');
  });

  test('legacy anomalies without punch data parse', () {
    final a = Anomaly.fromJson({
      'id': 'a2', 'type': 'MISSING_EXIT', 'severity': 'WARNING', 'status': 'RESOLVED',
      'employeeFirstName': null, 'employeeLastName': null, 'occuredAt': null, 'entryType': null,
      'employeeNumber': null, 'hasPhoto': false,
    });
    expect((a.employeeName, a.assistedByName, a.occuredAt, a.entryType, a.employeeNumber), ('', '', null, null, null));
    expect(a.isOpen, isFalse);
    expect(a.siteName, isNull);
  });

  test('status labels are in French', () {
    expect(anomalyStatusLabel('VALIDATED'), 'Validée');
    expect(anomalyStatusLabel('REJECTED'), 'Rejetée');
    expect(anomalyEntryTypeLabel('OUT'), 'Sortie');
  });
}
