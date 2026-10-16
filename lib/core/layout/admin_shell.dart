import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/session_provider.dart';
import '../theme.dart';
import 'breakpoints.dart';
import 'nav_item.dart';

/// Menu affiché dans le back-office.
class AdminMenuIndex extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final adminMenuIndexProvider = NotifierProvider<AdminMenuIndex, int>(AdminMenuIndex.new);

/// Coquille du back-office : menu latéral (≥ 1024 px), rail d'icônes (600–1023 px)
/// ou tiroir (< 600 px). Ajouter un menu = ajouter un [NavItem] à [menus].
class AdminShell extends ConsumerWidget {
  AdminShell({super.key, required this.menus}) : assert(menus.isNotEmpty);

  final List<NavItem> menus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = Breakpoints.of(context);
    final index = ref.watch(adminMenuIndexProvider).clamp(0, menus.length - 1);
    final identifier = ref.watch(sessionProvider).value?.identifier ?? '';
    void select(int i) => ref.read(adminMenuIndexProvider.notifier).select(i);
    void logout() => ref.read(sessionProvider.notifier).logout();
    final page = _Page(size: size, child: KeyedSubtree(key: ValueKey(index), child: Builder(builder: menus[index].builder)));

    if (size == WindowSize.compact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(menus[index].label),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(4), child: FlagStripe()),
        ),
        drawer: NavigationDrawer(
          selectedIndex: index,
          onDestinationSelected: (i) {
            Navigator.of(context).pop(); // referme le tiroir
            select(i);
          },
          children: [
            const _Brand(),
            for (final m in menus) NavigationDrawerDestination(icon: Icon(m.icon), label: Text(m.label)),
            const Divider(indent: 28, endIndent: 28),
            _UserTile(identifier: identifier, onLogout: logout),
          ],
        ),
        body: page,
      );
    }

    final navigation = size == WindowSize.expanded
        ? _SideMenu(menus: menus, index: index, onSelect: select, identifier: identifier, onLogout: logout)
        : _Rail(menus: menus, index: index, onSelect: select, onLogout: logout);
    return Scaffold(
      body: Column(children: [
        const FlagStripe(),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            navigation,
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ]),
        ),
      ]),
    );
  }
}

/// Zone de contenu : 1400 px au plus, marges de 16 px (téléphone) ou 24 px.
class _Page extends StatelessWidget {
  const _Page({required this.size, required this.child});
  final WindowSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SizedBox.expand(
            key: const Key('admin-page'),
            child: Padding(padding: EdgeInsets.all(size == WindowSize.compact ? 16 : 24), child: child),
          ),
        ),
      );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
        child: Row(children: [
          const Icon(Icons.fingerprint, color: AppColors.green, size: 28),
          const SizedBox(width: 12),
          Flexible(
            child: Text('Pointage',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ]),
      );
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.identifier, required this.onLogout});
  final String identifier;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(identifier, overflow: TextOverflow.ellipsis),
        trailing: IconButton(tooltip: 'Se déconnecter', icon: const Icon(Icons.logout), onPressed: onLogout),
      );
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.menus,
    required this.index,
    required this.onSelect,
    required this.identifier,
    required this.onLogout,
  });

  final List<NavItem> menus;
  final int index;
  final ValueChanged<int> onSelect;
  final String identifier;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => SizedBox(
        key: const Key('admin-side-menu'),
        width: 240,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _Brand(),
            Expanded(
              child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                for (var i = 0; i < menus.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      selected: i == index,
                      selectedColor: AppColors.green,
                      selectedTileColor: AppColors.green.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(menus[i].icon),
                      title: Text(menus[i].label, overflow: TextOverflow.ellipsis),
                      onTap: () => onSelect(i),
                    ),
                  ),
              ]),
            ),
            const Divider(height: 1),
            _UserTile(identifier: identifier, onLogout: onLogout),
          ]),
        ),
      );
}

/// Rail d'icônes maison : `NavigationRail` exige au moins deux destinations,
/// or l'admin peut n'avoir qu'un menu.
class _Rail extends StatelessWidget {
  const _Rail({required this.menus, required this.index, required this.onSelect, required this.onLogout});

  final List<NavItem> menus;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => SizedBox(
        key: const Key('admin-rail'),
        width: 80,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(children: [
            const SizedBox(height: 16),
            const Icon(Icons.fingerprint, color: AppColors.green, size: 32),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(children: [
                for (var i = 0; i < menus.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: i == index
                          ? IconButton.filledTonal(
                              tooltip: menus[i].label, icon: Icon(menus[i].icon), onPressed: () => onSelect(i))
                          : IconButton(tooltip: menus[i].label, icon: Icon(menus[i].icon), onPressed: () => onSelect(i)),
                    ),
                  ),
              ]),
            ),
            IconButton(tooltip: 'Se déconnecter', icon: const Icon(Icons.logout), onPressed: onLogout),
            const SizedBox(height: 16),
          ]),
        ),
      );
}
