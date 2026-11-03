import 'package:flutter/material.dart';

import '../core/role.dart';

/// Une entrée de la barre latérale du back-office.
class AdminNavItem {
  const AdminNavItem({required this.path, required this.label, required this.icon});

  final String path;
  final String label;
  final IconData icon;
}

/// Une rubrique de la barre latérale (VUE D'ENSEMBLE, GESTION…).
class AdminNavGroup {
  const AdminNavGroup({required this.label, required this.items, this.adminOnly = false});

  final String label;
  final List<AdminNavItem> items;

  /// Réservée à l'ADMIN (les annuaires et leurs sites).
  final bool adminOnly;
}

abstract final class AdminPaths {
  static const signIn = '/connexion';
  static const dashboard = '/';
  static const employees = '/employes';
  static const anomalies = '/anomalies';
  static const timeEntries = '/pointages';
  static const directories = '/annuaires';
}

const adminNavGroups = [
  AdminNavGroup(label: "Vue d'ensemble", items: [
    AdminNavItem(path: AdminPaths.dashboard, label: 'Tableau de bord', icon: Icons.space_dashboard_outlined),
  ]),
  AdminNavGroup(label: 'Gestion', items: [
    AdminNavItem(path: AdminPaths.employees, label: 'Employés', icon: Icons.badge_outlined),
    AdminNavItem(path: AdminPaths.anomalies, label: 'Anomalies', icon: Icons.report_problem_outlined),
    AdminNavItem(path: AdminPaths.timeEntries, label: 'Pointages', icon: Icons.schedule_outlined),
  ]),
  AdminNavGroup(label: 'Administration', adminOnly: true, items: [
    AdminNavItem(path: AdminPaths.directories, label: 'Annuaires', icon: Icons.account_tree_outlined),
  ]),
];

/// Les rubriques visibles pour ce rôle.
List<AdminNavGroup> navGroupsFor(Role role) =>
    [for (final g in adminNavGroups) if (!g.adminOnly || role == Role.admin) g];

/// L'entrée correspondant à [location] (la plus longue qui la préfixe), pour le titre de la page.
AdminNavItem? navItemAt(String location) {
  final matches = [
    for (final g in adminNavGroups)
      for (final i in g.items)
        if (location == i.path || (i.path != '/' && location.startsWith('${i.path}/'))) i,
  ]..sort((a, b) => b.path.length.compareTo(a.path.length));
  return matches.isEmpty ? null : matches.first;
}
