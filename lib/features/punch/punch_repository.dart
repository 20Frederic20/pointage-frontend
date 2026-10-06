import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';

class TimeEntry {
  TimeEntry({required this.entryType, required this.occurredAt});

  final String entryType; // IN / OUT, décidé par le serveur
  final DateTime occurredAt;

  bool get isIn => entryType == 'IN';

  factory TimeEntry.fromJson(Map<String, dynamic> j) => TimeEntry(
        entryType: j['entry_type'] as String,
        // le backend écrit "occured_at"
        occurredAt: DateTime.parse((j['occured_at'] ?? j['created_at']) as String).toLocal(),
      );
}

class PunchRepository {
  PunchRepository(this._api);
  final ApiClient _api;

  Future<TimeEntry> punch(String employeeNumber, {String? accessToken}) async {
    final pos = await _currentPosition();
    final json = await _api.post('/time-entries', {
      'employee_number': employeeNumber,
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'source': 'MOBILE',
      'idempotency_key': _randomKey(),
    }, accessToken: accessToken);
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

  static String _randomKey() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}

final punchRepositoryProvider = Provider((ref) => PunchRepository(ref.watch(apiClientProvider)));
