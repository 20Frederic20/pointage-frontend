import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/state_views.dart';
import '../directory_admin_controller.dart';
import '../directory_model.dart';
import '../directory_tree.dart';
import '../widgets/directory_detail_panel.dart';
import '../widgets/directory_form_dialog.dart';
import '../widgets/directory_tree_view.dart';

/// L'entreprise d'un service (null si [directoryId] est une entreprise).
Directory? _companyOf(List<DirectoryNode> tree, String directoryId) {
  for (final root in tree) {
    if (root.directory.id == directoryId) return null;
    if (findNode(root.children, directoryId) != null) return root.directory;
  }
  return null;
}

/// Le panneau de l'élément sélectionné, lu en direct dans l'arbre (il suit les actions).
class _SelectionDetail extends ConsumerWidget {
  const _SelectionDetail({required this.selection});
  final DirectorySelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(directoryAdminControllerProvider).value ?? const [];
    if (selection.isSite) {
      final found = findSite(tree, selection.id);
      if (found == null) return const Center(child: Text('Site introuvable.'));
      return SiteDetailPanel(key: ValueKey('site-${selection.id}'), site: found.$1, owner: found.$2);
    }
    final node = findNode(tree, selection.id);
    if (node == null) return const Center(child: Text('Annuaire introuvable.'));
    return DirectoryDetailPanel(key: ValueKey('dir-${selection.id}'), node: node, company: _companyOf(tree, node.directory.id));
  }
}

/// Back-office (ADMIN) : entreprises, services et sites ; détail à droite sur grand écran, en page sinon.
class DirectoryWebScreen extends ConsumerWidget {
  const DirectoryWebScreen({super.key});

  void _open(BuildContext context, WidgetRef ref, DirectorySelection selection) {
    ref.read(directorySelectionProvider.notifier).select(selection);
    if (Breakpoints.of(context) == WindowSize.expanded) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(selection.isSite ? 'Site' : 'Annuaire')),
        body: SafeArea(child: _SelectionDetail(selection: selection)),
      ),
    ));
  }

  Future<void> _createCompany(BuildContext context, WidgetRef ref) async {
    final r = await showDirectoryFormDialog(context, title: 'Nouvelle entreprise');
    if (r == null) return;
    final error = await ref.read(directoryAdminControllerProvider.notifier).createDirectory(name: r.name, code: r.code);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.red, content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(directoryAdminControllerProvider);
    final selection = ref.watch(directorySelectionProvider);
    final window = Breakpoints.of(context);
    final controller = ref.read(directoryAdminControllerProvider.notifier);

    final header = Row(children: [
      // Le titre est dans la barre du haut de la coquille.
      const Spacer(),
      FilledButton.tonal(onPressed: () => _createCompany(context, ref), child: const Text('+ Entreprise')),
    ]);

    final Widget list = switch (tree) {
      AsyncValue(:final value?) => DirectoryTreeView(
          nodes: value, selection: selection, onSelect: (s) => _open(context, ref, s)),
      AsyncError(:final error) => ErrorState(message: directoryErrorMessage(error), onRetry: controller.reload),
      _ => const Center(child: CircularProgressIndicator()),
    };

    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      const SizedBox(height: 12),
      Expanded(child: list),
    ]);
    if (window != WindowSize.expanded) return left;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: 380, child: left),
      const VerticalDivider(width: 32),
      Expanded(
        child: selection == null
            ? const EmptyState(icon: Icons.account_tree_outlined, message: 'Sélectionnez une entreprise, un service ou un site.')
            : _SelectionDetail(selection: selection),
      ),
    ]);
  }
}
