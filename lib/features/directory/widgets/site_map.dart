import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../directory_model.dart';

/// Centre par défaut quand aucun site n'a de position : Cotonou.
const defaultMapCenter = LatLng(6.3654, 2.4183);

/// Fond de carte OpenStreetMap (gratuit, sans clé). Null en test : pas d'accès réseau.
final mapTilesProvider = Provider<TileLayer?>((ref) => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'bj.pointage.pointage',
    ));

LatLng? _point(Site s) => s.hasPosition ? LatLng(s.latitude!, s.longitude!) : null;

class _Pin extends StatelessWidget {
  const _Pin({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Icon(Icons.location_on, color: color, size: 36);
}

/// Les sites placés sur la carte (le site mis en avant en rouge). « Aucune position » sinon.
class SiteMap extends ConsumerWidget {
  const SiteMap({super.key, required this.sites, this.highlightedId, this.height = 220});

  final List<Site> sites;
  final String? highlightedId;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placed = [for (final s in sites) if (_point(s) case final p?) (s, p)];
    if (placed.isEmpty) {
      return SizedBox(
        height: height,
        child: Card(margin: EdgeInsets.zero, child: const Center(child: Text('Aucun site placé sur la carte'))),
      );
    }
    final center = LatLng(
      placed.map((e) => e.$2.latitude).reduce((a, b) => a + b) / placed.length,
      placed.map((e) => e.$2.longitude).reduce((a, b) => a + b) / placed.length,
    );
    final tiles = ref.watch(mapTilesProvider);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          // La caméra ne suit pas un nouveau centre : on la recrée quand les sites bougent.
          key: ValueKey((center.latitude, center.longitude, placed.length)),
          options: MapOptions(initialCenter: center, initialZoom: placed.length == 1 ? 15 : 12),
          children: [
            ?tiles,
            MarkerLayer(markers: [
              for (final (site, point) in placed)
                Marker(
                  point: point,
                  width: 36,
                  height: 36,
                  alignment: Alignment.topCenter,
                  child: Tooltip(
                    message: site.name,
                    child: _Pin(color: site.id == highlightedId ? Colors.red : scheme.primary),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Carte où un clic pose (ou déplace) le point d'un site.
class SitePickerMap extends ConsumerWidget {
  const SitePickerMap({super.key, required this.point, required this.center, required this.onPick, this.height = 260});

  final LatLng? point;
  final LatLng center;
  final ValueChanged<LatLng> onPick;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(mapTilesProvider);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(initialCenter: point ?? center, initialZoom: 14, onTap: (_, p) => onPick(p)),
          children: [
            ?tiles,
            if (point case final p?)
              MarkerLayer(markers: [
                Marker(point: p, width: 36, height: 36, alignment: Alignment.topCenter, child: const _Pin(color: Colors.red)),
              ]),
          ],
        ),
      ),
    );
  }
}
