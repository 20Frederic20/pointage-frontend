import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/punch/punch_repository.dart';

/// Repository de pointage en mémoire : enregistre les clés d'idempotence reçues.
class FakePunchRepository implements PunchRepository {
  Object? lookupError;
  Object? punchForError;
  final List<String?> keys = [];
  final List<({String employeeNumber, List<int> photo, String contentType})>
  sent = [];

  @override
  Future<Colleague> lookupColleague(
    String accessToken,
    String employeeNumber,
  ) async {
    if (lookupError case final e?) throw e;
    return Colleague(
      employeeNumber: employeeNumber,
      firstName: 'Ana',
      lastName: 'Dossou',
    );
  }

  @override
  Future<TimeEntry> punchFor(
    String accessToken, {
    required String employeeNumber,
    required List<int> photo,
    required String contentType,
    String? idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    sent.add((
      employeeNumber: employeeNumber,
      photo: photo,
      contentType: contentType,
    ));
    if (punchForError case final e?) throw e;
    return TimeEntry(
      entryType: 'IN',
      occurredAt: DateTime(2026, 10, 27, 8, 5),
      validationStatus: 'PENDING',
    );
  }

  @override
  Future<TimeEntry> punch(String accessToken) => throw UnimplementedError();
}

ApiException notFound() => ApiException('Élément introuvable.', status: 404);
