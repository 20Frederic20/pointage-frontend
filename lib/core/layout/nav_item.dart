import 'package:flutter/widgets.dart';

/// Une entrée de navigation : un menu de l'admin ou un onglet du mobile.
class NavItem {
  const NavItem({required this.label, required this.icon, required this.builder});

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}
