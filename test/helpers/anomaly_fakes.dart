import 'dart:typed_data';

import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/paged.dart';
import 'package:pointage/features/anomaly/anomaly_model.dart';
import 'package:pointage/features/anomaly/anomaly_repository.dart';

Anomaly fakeAnomaly(int n, {String status = 'OPEN', bool hasPhoto = false, String? siteName}) => Anomaly(
      id: 'an$n',
      type: 'ASSISTED_POINTING',
      severity: 'BLOCKING',
      status: status,
      employeeId: 'emp$n',
      employeeNumber: 'EMP${n.toString().padLeft(7, '0')}',
      employeeFirstName: 'Ana$n',
      employeeLastName: 'Dossou',
      assistedByFirstName: 'Paul',
      assistedByLastName: 'Kpade',
      occuredAt: DateTime(2026, 10, 27, 8, 5),
      entryType: 'IN',
      hasPhoto: hasPhoto,
      siteName: siteName,
    );

/// 1x1 PNG.
final tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Repository en mémoire : une décision change le statut, donc l'anomalie quitte le filtre `OPEN`.
class FakeAnomalyRepository implements AnomalyRepository {
  FakeAnomalyRepository([List<Anomaly>? all]) : all = all ?? [for (var n = 1; n <= 3; n++) fakeAnomaly(n)];

  final List<Anomaly> all;
  final List<String?> listStatuses = [];
  final List<({String id, String decision, String? comment})> decisions = [];
  Object? decisionError;
  Object? listError;

  /// Le modèle de lecture est en retard : une décision réussit mais `list` renvoie encore l'ancien état.
  bool readModelLags = false;

  @override
  Future<Paged<Anomaly>> list(String accessToken, {String? status, int limit = 20, int offset = 0}) async {
    listStatuses.add(status);
    if (listError case final e?) throw e;
    final matching = all.where((a) => status == null || a.status == status).toList();
    return Paged(items: matching.skip(offset).take(limit).toList(), total: matching.length);
  }

  @override
  Future<Uint8List> photo(String accessToken, String id) async => tinyPng;

  Future<Anomaly> _decide(String id, String decision, String? comment, String status) async {
    decisions.add((id: id, decision: decision, comment: comment));
    if (decisionError case final e?) throw e;
    final i = all.indexWhere((a) => a.id == id);
    final old = all[i];
    final decided = Anomaly(
      id: old.id, type: old.type, severity: old.severity, status: status,
      employeeNumber: old.employeeNumber, employeeFirstName: old.employeeFirstName,
      employeeLastName: old.employeeLastName, assistedByFirstName: old.assistedByFirstName,
      assistedByLastName: old.assistedByLastName, occuredAt: old.occuredAt, entryType: old.entryType,
      hasPhoto: old.hasPhoto, decisionComment: comment, siteName: old.siteName,
    );
    if (!readModelLags) all[i] = decided;
    return decided;
  }

  @override
  Future<Anomaly> validate(String accessToken, String id, {String? comment}) =>
      _decide(id, 'validate', comment, 'VALIDATED');

  @override
  Future<Anomaly> reject(String accessToken, String id, String comment) =>
      _decide(id, 'reject', comment, 'REJECTED');
}

ApiException alreadyDecided() => ApiException('Cette anomalie a déjà été traitée.', status: 409);
