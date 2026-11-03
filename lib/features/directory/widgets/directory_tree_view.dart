import 'package:flutter/material.dart';

import '../directory_admin_controller.dart';
import '../directory_model.dart';
import '../directory_tree.dart';

/// « désactivé », « bloqué par » suivi de l'entreprise, ou rien.
String? blockLabel({required bool ownActive, Directory? blockedBy}) =>
    !ownActive ? 'désactivé' : (blockedBy != null ? 'bloqué par ${blockedBy.name}' : null);

/// Arbre entreprises → services → sites ; les éléments bloqués sont grisés.
class DirectoryTreeView extends StatelessWidget {
  const DirectoryTreeView({super.key, required this.nodes, required this.selection, required this.onSelect});

  final List<DirectoryNode> nodes;
  final DirectorySelection? selection;
  final ValueChanged<DirectorySelection> onSelect;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void add(DirectoryNode node, int depth) {
      final d = node.directory;
      rows.add(_Row(
        key: ValueKey('dir-${d.id}'),
        depth: depth,
        icon: d.isCompany ? Icons.business_outlined : Icons.account_tree_outlined,
        title: d.name,
        subtitle: d.code,
        bold: d.isCompany,
        status: blockLabel(ownActive: d.active, blockedBy: node.blockedBy),
        selected: selection == (isSite: false, id: d.id),
        onTap: () => onSelect((isSite: false, id: d.id)),
      ));
      for (final site in node.sites) {
        rows.add(_Row(
          key: ValueKey('site-${site.id}'),
          depth: depth + 1,
          icon: Icons.place_outlined,
          title: site.name,
          tag: site.isPrincipal ? 'principal' : null,
          status: blockLabel(ownActive: site.active, blockedBy: node.blocked ? (node.blockedBy ?? d) : null),
          selected: selection == (isSite: true, id: site.id),
          onTap: () => onSelect((isSite: true, id: site.id)),
        ));
      }
      for (final child in node.children) {
        add(child, depth + 1);
      }
    }

    for (final node in nodes) {
      add(node, 0);
    }
    if (rows.isEmpty) return const Center(child: Text('Aucun annuaire : créez une entreprise.'));
    return ListView(children: rows);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.depth,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.tag,
    this.status,
    this.bold = false,
  });

  final int depth;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? tag;
  final String? status;
  final bool bold;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = status != null;
    final color = muted ? theme.disabledColor : null;
    return Material(
      color: selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8 + 20.0 * depth, 8, 8, 8),
          child: Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: bold ? FontWeight.bold : null, color: color)),
                Wrap(spacing: 8, children: [
                  if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: color)),
                  if (tag != null)
                    Text(tag!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.green.shade700)),
                  if (status != null) Text(status!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
