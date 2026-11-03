import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/format.dart';
import '../../core/role.dart';
import '../../features/anomaly/anomaly_model.dart';
import '../../features/anomaly/anomaly_repository.dart';
import '../../features/anomaly/widgets/anomaly_detail_view.dart';
import '../../features/auth/session_provider.dart';
import '../../features/employee/employee_model.dart';
import '../../features/employee/employee_repository.dart';
import '../../features/employee/screens/employee_detail_page.dart';
import '../admin_routes.dart';

/// Un résultat de la recherche.
class SearchResult {
  const SearchResult({required this.label, required this.group, required this.icon, required this.open, this.detail});

  final String label;
  final String group;
  final IconData icon;
  final String? detail;

  /// Reçoit le contexte de la coquille (la recherche est déjà fermée).
  final void Function(BuildContext shell) open;
}

/// Recherche du back-office (Ctrl+K) : les écrans, les employés (nom ou matricule) et les anomalies ouvertes.
Future<void> showAdminSearch(BuildContext context) async {
  final picked = await showDialog<SearchResult>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (_) => const _AdminSearch(),
  );
  if (picked != null && context.mounted) picked.open(context);
}

/// Texte comparable : minuscules, sans accents courants.
String _fold(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');

bool _matches(String query, Iterable<String?> fields) =>
    fields.whereType<String>().any((f) => _fold(f).contains(query));

class _AdminSearch extends ConsumerStatefulWidget {
  const _AdminSearch();

  @override
  ConsumerState<_AdminSearch> createState() => _AdminSearchState();
}

class _AdminSearchState extends ConsumerState<_AdminSearch> {
  final _controller = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);
  Timer? _debounce;

  /// Chargés une fois à la première recherche, puis filtrés ici (le backend ne cherche que par matricule exact).
  List<Employee>? _employees;
  List<Anomaly>? _anomalies;
  List<SearchResult> _results = const [];
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _results = _pages('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<SearchResult> _pages(String q) {
    final role = ref.read(sessionProvider).value?.role ?? Role.employee;
    return [
      for (final g in navGroupsFor(role))
        for (final item in g.items)
          if (q.isEmpty || _matches(q, [item.label]))
            SearchResult(
              label: item.label,
              group: 'Écrans',
              icon: item.icon,
              open: (shell) => shell.go(item.path),
            ),
    ];
  }

  void _onChanged() {
    final q = _fold(_controller.text.trim());
    setState(() {
      _results = _pages(q);
      _active = 0;
    });
    _debounce?.cancel();
    if (q.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 200), () => _searchRecords(q));
  }

  Future<void> _searchRecords(String q) async {
    try {
      final token = await ref.read(sessionProvider.notifier).accessToken();
      if (token == null) return;
      _employees ??= (await ref.read(employeeRepositoryProvider).list(token, limit: 200)).items;
      _anomalies ??= (await ref.read(anomalyRepositoryProvider).list(token, status: 'OPEN', limit: 50)).items;
    } catch (_) {
      // Les écrans restent trouvables si les données ne répondent pas.
    }
    if (!mounted || _fold(_controller.text.trim()) != q) return;
    setState(() => _results = [
          ..._pages(q),
          for (final e in (_employees ?? const <Employee>[]).where(
                  (e) => _matches(q, [e.displayName, e.employeeNumber, e.companyName])).take(6))
            SearchResult(
              label: e.displayName,
              detail: [if (e.displayName != e.employeeNumber) e.employeeNumber, ?e.companyName].join(' · '),
              group: 'Employés',
              icon: Icons.badge_outlined,
              open: (shell) {
                shell.go(AdminPaths.employees);
                Navigator.of(shell).push(MaterialPageRoute<void>(builder: (_) => EmployeeDetailPage(id: e.id)));
              },
            ),
          for (final a in (_anomalies ?? const <Anomaly>[]).where(
                  (a) => _matches(q, [a.employeeName, a.employeeNumber, a.assistedByName])).take(6))
            SearchResult(
              label: a.employeeName,
              detail: 'Anomalie · ${formatDateTime(a.occuredAt)}',
              group: 'Anomalies en attente',
              icon: Icons.report_problem_outlined,
              open: (shell) {
                shell.go(AdminPaths.anomalies);
                Navigator.of(shell).push(MaterialPageRoute<void>(builder: (page) => Scaffold(
                      appBar: AppBar(title: const Text('Anomalie')),
                      body: SafeArea(
                          child: AnomalyDetailView(anomaly: a, onDecided: () => Navigator.of(page).maybePop())),
                    )));
              },
            ),
        ]);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && _results.isNotEmpty) {
      setState(() => _active = (_active + 1) % _results.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && _results.isNotEmpty) {
      setState(() => _active = (_active - 1 + _results.length) % _results.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && _results.isNotEmpty) {
      Navigator.of(context).pop(_results[_active]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    String? lastGroup;
    return Dialog(
      key: const ValueKey('admin-search'),
      alignment: const Alignment(0, -0.6),
      backgroundColor: c.card,
      insetPadding: const EdgeInsets.all(KiteSpace.lg),
      shape: RoundedRectangleBorder(borderRadius: KiteRadius.allLg, side: BorderSide(color: c.border)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.all(KiteSpace.md),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Rechercher un écran, un employé, une anomalie…',
                prefixIcon: Icon(Icons.search, size: 18),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(KiteSpace.xl),
                    child: Text('Aucun résultat.', style: t.muted, textAlign: TextAlign.center),
                  )
                : ListView(shrinkWrap: true, padding: const EdgeInsets.all(KiteSpace.sm), children: [
                    for (final (i, r) in _results.indexed) ...[
                      if (r.group != lastGroup) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(KiteSpace.md, KiteSpace.sm, KiteSpace.md, KiteSpace.xs),
                          child: Text((lastGroup = r.group).toUpperCase(),
                              style: t.muted.copyWith(fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
                        ),
                      ],
                      Material(
                        color: i == _active ? c.accent : Colors.transparent,
                        borderRadius: KiteRadius.allSm,
                        child: ListTile(
                          dense: true,
                          leading: Icon(r.icon, size: 18, color: c.mutedForeground),
                          title: Text(r.label, style: t.small, overflow: TextOverflow.ellipsis),
                          subtitle: r.detail == null || r.detail!.isEmpty
                              ? null
                              : Text(r.detail!, style: t.muted.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.of(context).pop(r),
                        ),
                      ),
                    ],
                  ]),
          ),
        ]),
      ),
    );
  }
}
