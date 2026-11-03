import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../core/role.dart';
import '../features/auth/session_provider.dart';
import 'admin_routes.dart';
import 'search/admin_search.dart';

/// Coquille du back-office, d'après le template Kite : barre latérale à rubriques
/// (≥ 640 px) ou tiroir (téléphone), barre du haut avec le titre et la recherche.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KiteColors.of(context);
    final mobile = KiteBreak.isMobile(context);
    final role = ref.watch(sessionProvider).value?.role ?? Role.employee;
    final sidebar = _SidebarBody(location: location, groups: navGroupsFor(role), inDrawer: mobile);

    // Ctrl+K partout derrière la connexion (⌘K sur macOS).
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => showAdminSearch(context),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => showAdminSearch(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: c.background,
          drawer: mobile ? Drawer(backgroundColor: c.card, child: SafeArea(child: sidebar)) : null,
          body: SafeArea(
            child: Row(children: [
              if (!mobile)
                SizedBox(
                  width: 248,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: c.card, border: Border(right: BorderSide(color: c.border))),
                    child: sidebar,
                  ),
                ),
              Expanded(
                child: Column(children: [
                  _TopBar(location: location, mobile: mobile),
                  Expanded(child: child),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SidebarBody extends ConsumerWidget {
  const _SidebarBody({required this.location, required this.groups, required this.inDrawer});

  final String location;
  final List<AdminNavGroup> groups;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(KiteSpace.xl, KiteSpace.xl, KiteSpace.xl, KiteSpace.lg),
        child: Row(children: [
          Icon(Icons.fingerprint, size: 22, color: c.primary),
          const SizedBox(width: KiteSpace.sm),
          Text('Pointage', style: t.h4),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: KiteSpace.md), children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(KiteSpace.md, KiteSpace.md, KiteSpace.md, KiteSpace.xs),
              child: Text(group.label.toUpperCase(),
                  style: t.muted.copyWith(fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
            ),
            for (final item in group.items)
              _NavTile(
                item: item,
                active: navItemAt(location)?.path == item.path,
                onTap: () {
                  if (inDrawer) Navigator.of(context).pop(); // referme le tiroir
                  context.go(item.path);
                },
              ),
          ],
        ]),
      ),
      const Divider(height: 1),
      const _UserTile(),
    ]);
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.active, required this.onTap});

  final AdminNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final color = active ? c.foreground : c.mutedForeground;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? c.accent : Colors.transparent,
        borderRadius: KiteRadius.allSm,
        child: InkWell(
          borderRadius: KiteRadius.allSm,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KiteSpace.md, vertical: 10),
            child: Row(children: [
              Icon(item.icon, size: 18, color: color),
              const SizedBox(width: KiteSpace.md),
              Expanded(
                child: Text(item.label,
                    overflow: TextOverflow.ellipsis,
                    style: t.small.copyWith(color: color, fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Le matricule ou l'email, l'entreprise et le rôle de la session, et la déconnexion.
class _UserTile extends ConsumerWidget {
  const _UserTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    if (session == null) return const SizedBox.shrink();
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final name = session.identifier;
    return Padding(
      padding: const EdgeInsets.all(KiteSpace.md),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.muted, shape: BoxShape.circle),
          child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: t.small.copyWith(fontSize: 12)),
        ),
        const SizedBox(width: KiteSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: t.small, overflow: TextOverflow.ellipsis),
            Text([?session.companyName, session.role.label].join(' · '),
                style: t.muted.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis),
          ]),
        ),
        IconButton(
          tooltip: 'Se déconnecter',
          iconSize: 18,
          color: c.mutedForeground,
          icon: const Icon(Icons.logout),
          onPressed: () => ref.read(sessionProvider.notifier).logout(),
        ),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.location, required this.mobile});

  final String location;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: mobile ? KiteSpace.sm : KiteSpace.xl),
      decoration: BoxDecoration(color: c.card, border: Border(bottom: BorderSide(color: c.border))),
      child: Row(children: [
        if (mobile)
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Ouvrir le menu',
            color: c.mutedForeground,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        Expanded(
          child: Text(navItemAt(location)?.label ?? 'Pointage', style: t.large, overflow: TextOverflow.ellipsis),
        ),
        if (mobile)
          IconButton(
            tooltip: 'Rechercher',
            icon: const Icon(Icons.search),
            color: c.mutedForeground,
            onPressed: () => showAdminSearch(context),
          )
        else
          const _SearchTrigger(),
      ]),
    );
  }
}

/// Ouvre la recherche (comme Ctrl+K) : un bouton, pas un champ, pour ne pas concurrencer
/// les champs de recherche propres à chaque liste.
class _SearchTrigger extends StatelessWidget {
  const _SearchTrigger();

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    return Material(
      color: c.background,
      borderRadius: KiteRadius.allSm,
      child: InkWell(
        borderRadius: KiteRadius.allSm,
        onTap: () => showAdminSearch(context),
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: KiteSpace.md, vertical: 7),
          decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: KiteRadius.allSm),
          child: Row(children: [
            Icon(Icons.search, size: 15, color: c.mutedForeground),
            const SizedBox(width: KiteSpace.sm),
            Expanded(child: Text('Rechercher…', style: t.muted.copyWith(fontSize: 13))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: c.muted, borderRadius: BorderRadius.circular(4)),
              child: Text('Ctrl K', style: t.muted.copyWith(fontSize: 11)),
            ),
          ]),
        ),
      ),
    );
  }
}
