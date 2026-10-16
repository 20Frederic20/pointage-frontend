import 'package:flutter/material.dart';

import 'nav_item.dart';

/// Coquille de l'app mobile : barre de navigation en bas.
/// Un onglet n'est construit qu'à sa première visite, puis reste en vie.
class MobileShell extends StatefulWidget {
  // Non const : `tabs.length` n'est pas autorisé dans un initialiseur const.
  // ignore: prefer_const_constructors_in_immutables
  MobileShell({super.key, required this.tabs}) : assert(tabs.length >= 2, 'NavigationBar exige 2 onglets');

  final List<NavItem> tabs;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _index = 0;
  final _visited = <int>{0};

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: [
          for (var i = 0; i < widget.tabs.length; i++)
            _visited.contains(i) ? Builder(builder: widget.tabs[i].builder) : const SizedBox.shrink(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() {
            _index = i;
            _visited.add(i);
          }),
          destinations: [
            for (final t in widget.tabs) NavigationDestination(icon: Icon(t.icon), label: t.label),
          ],
        ),
      );
}
