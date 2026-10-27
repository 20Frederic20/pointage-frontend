import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/session_provider.dart';
import 'anomaly_model.dart';
import 'anomaly_repository.dart';

String anomalyErrorMessage(Object e) => switch (e) {
      ApiException(status: 404) => 'Anomalie introuvable.',
      ApiException(:final message) => message,
      _ => 'Connexion au serveur impossible, réessayez.',
    };

class AnomalyState {
  const AnomalyState({
    this.items = const [],
    this.total = 0,
    this.offset = 0,
    this.status = 'OPEN',
    this.loading = false,
    this.error,
  });

  static const limit = 20;

  final List<Anomaly> items;
  final int total;
  final int offset;

  /// Filtre de statut ; null = toutes. `OPEN` par défaut.
  final String? status;
  final bool loading;
  final String? error;

  bool get hasMore => offset + items.length < total;
  int get page => offset ~/ limit;
  int get pageCount => total == 0 ? 1 : (total + limit - 1) ~/ limit;

  AnomalyState copyWith({List<Anomaly>? items, int? total, int? offset, bool? loading, String? error}) => AnomalyState(
        items: items ?? this.items,
        total: total ?? this.total,
        offset: offset ?? this.offset,
        status: status,
        loading: loading ?? this.loading,
        error: error,
      );
}

class AnomalyController extends Notifier<AnomalyState> {
  int _generation = 0;

  /// Anomalies décidées ici, telles que renvoyées par le serveur. Le modèle de lecture peut avoir
  /// un temps de retard : tant qu'il renvoie encore une anomalie OPEN, on affiche la réponse du serveur.
  final Map<String, Anomaly> _decided = {};

  @override
  AnomalyState build() {
    ref.watch(sessionProvider.select((s) => s.value?.identifier));
    _generation++;
    _decided.clear();
    return const AnomalyState();
  }

  Future<void> refresh() => _fetch(state.offset);

  Future<void> setStatus(String? status) {
    state = AnomalyState(status: status, items: state.items, total: state.total, loading: state.loading);
    return _fetch(0);
  }

  Future<void> goToPage(int page) async {
    if (page < 0 || page >= state.pageCount) return;
    await _fetch(page * AnomalyState.limit);
  }

  /// Valide l'anomalie puis rafraîchit la liste. Renvoie le message d'erreur, ou null en cas de succès.
  Future<String?> validate(String id, {String? comment}) =>
      _decide((repo, token) => repo.validate(token, id, comment: comment));

  /// Rejette l'anomalie ([comment] obligatoire) puis rafraîchit la liste.
  Future<String?> reject(String id, String comment) => _decide((repo, token) => repo.reject(token, id, comment));

  /// Après un succès, la ligne est corrigée (ou retirée du filtre) avec la réponse du serveur avant
  /// le rechargement. Sur un 404 ou un 409, la liste est périmée : on la recharge aussi.
  Future<String?> _decide(Future<Anomaly> Function(AnomalyRepository, String) call) async {
    try {
      final token = await requireAccessToken(ref);
      final decided = await call(ref.read(anomalyRepositoryProvider), token);
      if (!ref.mounted) return null;
      _decided[decided.id] = decided;
      final (items, removed) = _overlay(state.items, state.status);
      state = state.copyWith(items: items, total: state.total - removed);
    } catch (e) {
      if (e case ApiException(status: 404 || 409) when ref.mounted) await refresh();
      return anomalyErrorMessage(e);
    }
    if (ref.mounted) await refresh();
    return null;
  }

  /// Applique les décisions locales à [items] ; renvoie la liste et le nombre de lignes retirées du filtre.
  (List<Anomaly>, int) _overlay(List<Anomaly> items, String? status) {
    final kept = <Anomaly>[];
    for (final item in items) {
      var shown = item;
      if (_decided[item.id] case final decided?) {
        if (item.isOpen) {
          shown = decided;
        } else {
          _decided.remove(item.id); // le modèle de lecture a rattrapé la décision
        }
      }
      if (status == null || shown.status == status) kept.add(shown);
    }
    return (kept, items.length - kept.length);
  }

  Future<void> _fetch(int offset) async {
    final generation = ++_generation;
    final status = state.status;
    state = state.copyWith(loading: true);
    try {
      final token = await requireAccessToken(ref);
      final page = await ref
          .read(anomalyRepositoryProvider)
          .list(token, status: status, limit: AnomalyState.limit, offset: offset);
      if (!_isCurrent(generation)) return;
      if (page.items.isEmpty && offset > 0 && page.total > 0) {
        return _fetch((page.total - 1) ~/ AnomalyState.limit * AnomalyState.limit);
      }
      final (items, removed) = _overlay(page.items, status);
      state = state.copyWith(items: items, total: page.total - removed, offset: offset, loading: false);
    } catch (e) {
      if (_isCurrent(generation)) state = state.copyWith(loading: false, error: anomalyErrorMessage(e));
    }
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final anomalyControllerProvider = NotifierProvider<AnomalyController, AnomalyState>(AnomalyController.new);

/// Selfie d'une anomalie. Pas de nouvel essai automatique.
final anomalyPhotoProvider = FutureProvider.autoDispose.family<Uint8List, String>(
  (ref, id) async => ref.read(anomalyRepositoryProvider).photo(await requireAccessToken(ref), id),
  retry: (_, _) => null,
);
