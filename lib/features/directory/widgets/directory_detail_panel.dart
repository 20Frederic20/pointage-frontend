import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../directory_admin_controller.dart';
import '../directory_model.dart';
import '../directory_tree.dart';
import 'directory_form_dialog.dart';
import 'directory_tree_view.dart';
import 'site_form_dialog.dart';
import 'site_map.dart';

/// Lance l'action ; son message d'erreur s'affiche dans une SnackBar.
Future<void> _report(BuildContext context, Future<String?> Function() action) async {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final error = await action();
  if (error != null) messenger.showSnackBar(SnackBar(backgroundColor: AppColors.red, content: Text(error)));
}

Future<bool> _confirmDeactivate(BuildContext context, String what) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Désactiver ?'),
        content: Text("$what n'acceptera plus de pointage ni de nouvelle affectation. Les affectations en cours sont conservées."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Désactiver')),
        ],
      ),
    ) ??
    false;

LatLng _centerOf(List<Site> sites) {
  final principal = sites.where((s) => s.hasPosition).firstOrNull;
  return principal == null ? defaultMapCenter : LatLng(principal.latitude!, principal.longitude!);
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.lines, this.status});
  final String title;
  final List<String> lines;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      for (final line in lines) Text(line, style: theme.textTheme.bodyMedium),
      if (status != null) Text(status!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
    ]);
  }
}

/// Détail d'un annuaire : infos, carte de ses sites, actions.
class DirectoryDetailPanel extends ConsumerWidget {
  const DirectoryDetailPanel({super.key, required this.node, this.company});

  final DirectoryNode node;

  /// L'entreprise d'un service (null pour une entreprise).
  final Directory? company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = node.directory;
    final controller = ref.read(directoryAdminControllerProvider.notifier);
    return ListView(padding: const EdgeInsets.all(16), children: [
      _Header(
        title: d.name,
        lines: ['Code : ${d.code}', company == null ? 'Entreprise' : 'Service de ${company!.name}'],
        status: blockLabel(ownActive: d.active, blockedBy: node.blockedBy),
      ),
      const SizedBox(height: 12),
      SiteMap(sites: node.sites),
      const SizedBox(height: 8),
      Text(node.sites.isEmpty ? 'Aucun site' : 'Sites : ${node.sites.map((s) => s.name).join(', ')}'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton(
          onPressed: () async {
            final r = await showDirectoryFormDialog(context, title: "Modifier l'annuaire", name: d.name, code: d.code);
            if (r != null && context.mounted) await _report(context, () => controller.updateDirectory(d.id, name: r.name, code: r.code));
          },
          child: const Text('Modifier'),
        ),
        OutlinedButton(
          onPressed: () async {
            final r = await showDirectoryFormDialog(context, title: 'Nouveau service de ${d.name}');
            if (r != null && context.mounted) await _report(context, () => controller.createDirectory(name: r.name, code: r.code, parentId: d.id));
          },
          child: const Text('+ Service'),
        ),
        OutlinedButton(
          onPressed: () async {
            final r = await showSiteFormDialog(context, title: 'Nouveau site de ${d.name}', center: _centerOf(node.sites));
            if (r != null && context.mounted) {
              await _report(context, () => controller.createSite(d.id,
                  name: r.name, latitude: r.latitude, longitude: r.longitude, address: r.address));
            }
          },
          child: const Text('+ Site'),
        ),
        if (d.active)
          OutlinedButton(
            onPressed: () async {
              if (await _confirmDeactivate(context, d.isCompany ? "L'entreprise, ses services et leurs sites" : 'Ce service et ses sites') && context.mounted) {
                await _report(context, () => controller.setDirectoryActive(d.id, false));
              }
            },
            child: const Text('Désactiver'),
          )
        else
          OutlinedButton(
            onPressed: () async => await _report(context, () => controller.setDirectoryActive(d.id, true)),
            child: const Text('Réactiver'),
          ),
      ]),
    ]);
  }
}

/// Détail d'un site : infos, carte, actions.
class SiteDetailPanel extends ConsumerWidget {
  const SiteDetailPanel({super.key, required this.site, required this.owner});

  final Site site;
  final DirectoryNode owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(directoryAdminControllerProvider.notifier);
    return ListView(padding: const EdgeInsets.all(16), children: [
      _Header(
        title: site.name,
        lines: [
          'Site de ${owner.directory.name}${site.isPrincipal ? ' · principal' : ''}',
          if (site.address != null) site.address!,
        ],
        status: blockLabel(ownActive: site.active, blockedBy: owner.blocked ? (owner.blockedBy ?? owner.directory) : null),
      ),
      const SizedBox(height: 12),
      SiteMap(sites: [site], highlightedId: site.id),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton(
          onPressed: () async {
            final r = await showSiteFormDialog(context, title: 'Modifier le site', site: site);
            if (r != null && context.mounted) {
              await _report(context, () => controller.updateSite(site.id,
                  name: r.name, latitude: r.latitude, longitude: r.longitude, address: r.address));
            }
          },
          child: const Text('Modifier'),
        ),
        if (!site.isPrincipal && site.active)
          OutlinedButton(
            onPressed: () async => await _report(context, () => controller.makePrincipal(site.id)),
            child: const Text('Rendre principal'),
          ),
        if (site.active)
          OutlinedButton(
            onPressed: () async {
              if (await _confirmDeactivate(context, 'Ce site') && context.mounted) {
                await _report(context, () => controller.setSiteActive(site.id, false));
              }
            },
            child: const Text('Désactiver'),
          )
        else
          OutlinedButton(
            onPressed: () async => await _report(context, () => controller.setSiteActive(site.id, true)),
            child: const Text('Réactiver'),
          ),
      ]),
    ]);
  }
}
