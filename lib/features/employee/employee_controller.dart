import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/session_provider.dart';
import 'employee_model.dart';
import 'employee_repository.dart';

/// Message affiché pour une erreur du module.
String employeeErrorMessage(Object e) => switch (e) {
      ApiException(status: 404) => 'Employé introuvable.',
      ApiException(:final message) => message,
      _ => 'Connexion au serveur impossible, réessayez.',
    };

class EmployeeState {
  const EmployeeState({
    this.items = const [],
    this.total = 0,
    this.offset = 0,
    this.filters = const EmployeeFilters(),
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  static const limit = 20;

  /// Fenêtre affichée : de [offset] à `offset + items.length`, sur [total].
  /// Le web remplace la fenêtre page par page ; le mobile l'allonge ([offset] reste 0).
  final List<Employee> items;
  final int total;
  final int offset;
  final EmployeeFilters filters;
  final bool loading;
  final bool loadingMore;
  final String? error;

  bool get hasMore => offset + items.length < total;
  int get page => offset ~/ limit;
  int get pageCount => total == 0 ? 1 : (total + limit - 1) ~/ limit;

  /// [error] n'est pas recopié : un nouvel état l'efface, sauf s'il est fourni.
  EmployeeState copyWith({
    List<Employee>? items,
    int? total,
    int? offset,
    EmployeeFilters? filters,
    bool? loading,
    bool? loadingMore,
    String? error,
  }) =>
      EmployeeState(
        items: items ?? this.items,
        total: total ?? this.total,
        offset: offset ?? this.offset,
        filters: filters ?? this.filters,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
      );
}

/// Liste des employés, partagée par l'écran web (pages) et l'écran mobile (défilement infini).
class EmployeeController extends Notifier<EmployeeState> {
  /// Numéro de la dernière requête lancée : toute réponse plus ancienne est ignorée.
  int _generation = 0;

  @override
  EmployeeState build() {
    ref.watch(sessionProvider.select((s) => s.value?.identifier)); // repart à zéro quand l'utilisateur change
    return const EmployeeState();
  }

  Future<void> refresh() => _fetch(state.offset);

  Future<void> setFilters(EmployeeFilters filters) {
    state = state.copyWith(filters: filters);
    return _fetch(0);
  }

  Future<void> goToPage(int page) async {
    if (page < 0 || page >= state.pageCount) return;
    await _fetch(page * EmployeeState.limit);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final generation = _generation;
    final filters = state.filters;
    final next = state.offset + state.items.length;
    state = state.copyWith(loadingMore: true);
    try {
      final token = await requireAccessToken(ref);
      final page = await ref
          .read(employeeRepositoryProvider)
          .list(token, filters: filters, limit: EmployeeState.limit, offset: next);
      if (!_isCurrent(generation)) return;
      state = state.copyWith(items: [...state.items, ...page.items], total: page.total, loadingMore: false);
    } catch (e) {
      if (_isCurrent(generation)) state = state.copyWith(loadingMore: false, error: employeeErrorMessage(e));
    }
  }

  Future<void> _fetch(int offset) async {
    final generation = ++_generation;
    final filters = state.filters;
    state = state.copyWith(loading: true, loadingMore: false);
    try {
      final token = await requireAccessToken(ref);
      final page = await ref
          .read(employeeRepositoryProvider)
          .list(token, filters: filters, limit: EmployeeState.limit, offset: offset);
      if (!_isCurrent(generation)) return;
      // La page demandée n'existe plus (le total a baissé) : on revient à la dernière.
      if (page.items.isEmpty && offset > 0 && page.total > 0) {
        return _fetch((page.total - 1) ~/ EmployeeState.limit * EmployeeState.limit);
      }
      state = state.copyWith(items: page.items, total: page.total, offset: offset, loading: false);
    } catch (e) {
      if (_isCurrent(generation)) state = state.copyWith(loading: false, error: employeeErrorMessage(e));
    }
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final employeeControllerProvider = NotifierProvider<EmployeeController, EmployeeState>(EmployeeController.new);
