import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';

class TimeEntry {
  TimeEntry({required this.entryType, required this.occurredAt, this.validationStatus = 'COUNTED'});

  final String entryType; // IN / OUT, décidé par le serveur
  final DateTime occurredAt;

  /// COUNTED, ou PENDING pour un pointage assisté en attente de validation.
  final String validationStatus;

  bool get isIn => entryType == 'IN';

  factory TimeEntry.fromJson(Map<String, dynamic> j) => TimeEntry(
        entryType: j['entry_type'] as String,
        // le backend écrit "occured_at"
        occurredAt: DateTime.parse((j['occured_at'] ?? j['created_at']) as String).toLocal(),
        validationStatus: (j['validation_status'] as String?) ?? 'COUNTED',
      );
}

class Colleague {
  const Colleague({required this.employeeNumber, this.firstName, this.lastName});

  final String employeeNumber;
  final String? firstName;
  final String? lastName;

  String get displayName {
    final name = [firstName, lastName].whereType<String>().where((p) => p.isNotEmpty).join(' ');
    return name.isEmpty ? employeeNumber : name;
  }

  factory Colleague.fromJson(Map<String, dynamic> j) => Colleague(
        employeeNumber: j['employeeNumber'] as String,
        firstName: j['firstName'] as String?,
        lastName: j['lastName'] as String?,
      );
}

class PunchRepository {
  PunchRepository(this._api);
  final ApiClient _api;

  /// L'employé est lu dans le jeton ; arrivée ou départ est décidé par le serveur.
  Future<TimeEntry> punch(String accessToken) async {
    final pos = await _currentPosition();
    final json = await _api.post('/time-entries', {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'source': 'MOBILE',
      'idempotency_key': newIdempotencyKey(),
    }, accessToken: accessToken);
    return TimeEntry.fromJson(json);
  }

  Future<Colleague> lookupColleague(String accessToken, String employeeNumber) async {
    final json = await _api.get('/time-entries/assisted/employees/${Uri.encodeComponent(employeeNumber)}',
        accessToken: accessToken);
    return Colleague.fromJson(json as Map<String, dynamic>);
  }

  /// Pointage assisté avec selfie. [idempotencyKey] : à réutiliser pour réessayer le même envoi.
  Future<TimeEntry> punchFor(
    String accessToken, {
    required String employeeNumber,
    required List<int> photo,
    required String contentType,
    String? idempotencyKey,
  }) async {
    final pos = await _currentPosition();
    final json = await _api.postMultipart('/time-entries/assisted', {
      'employee_number': employeeNumber,
      'latitude': pos.latitude.toString(),
      'longitude': pos.longitude.toString(),
      'idempotency_key': idempotencyKey ?? newIdempotencyKey(),
    },
        fileField: 'photo',
        bytes: photo,
        filename: contentType == 'image/png' ? 'selfie.png' : 'selfie.jpg',
        contentType: contentType,
        accessToken: accessToken);
    return TimeEntry.fromJson(json);
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw ApiException('Activez la localisation pour pointer.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw ApiException('Autorisez la localisation pour pointer.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
  }
}

/// Clé d'idempotence aléatoire : une par tentative de pointage.
String newIdempotencyKey() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

final punchRepositoryProvider = Provider((ref) => PunchRepository(ref.watch(apiClientProvider)));
