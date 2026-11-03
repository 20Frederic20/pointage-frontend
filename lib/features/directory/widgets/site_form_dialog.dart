import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../directory_model.dart';
import 'site_map.dart';

typedef SiteFormResult = ({String name, String? address, double latitude, double longitude});

/// Nom, adresse et position d'un site ; un clic sur la carte pose le point. Renvoie null si annulé.
Future<SiteFormResult?> showSiteFormDialog(BuildContext context,
        {required String title, Site? site, LatLng center = defaultMapCenter}) =>
    showDialog<SiteFormResult>(
      context: context,
      builder: (_) => SiteFormDialog(title: title, site: site, center: center),
    );

class SiteFormDialog extends StatefulWidget {
  const SiteFormDialog({super.key, required this.title, this.site, this.center = defaultMapCenter});
  final String title;
  final Site? site;
  final LatLng center;

  @override
  State<SiteFormDialog> createState() => _SiteFormDialogState();
}

class _SiteFormDialogState extends State<SiteFormDialog> {
  late final _name = TextEditingController(text: widget.site?.name ?? '');
  late final _address = TextEditingController(text: widget.site?.address ?? '');
  late LatLng? _point = widget.site?.hasPosition ?? false ? LatLng(widget.site!.latitude!, widget.site!.longitude!) : null;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _point != null;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse (facultative)')),
              const SizedBox(height: 12),
              Text(
                _point == null
                    ? 'Cliquez sur la carte pour placer le site.'
                    : 'Position : ${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              SitePickerMap(
                key: const Key('site-form-map'),
                point: _point,
                center: widget.center,
                onPick: (p) => setState(() => _point = p),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: _valid
                ? () => Navigator.of(context).pop((
                      name: _name.text.trim(),
                      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
                      latitude: _point!.latitude,
                      longitude: _point!.longitude,
                    ))
                : null,
            child: const Text('Enregistrer'),
          ),
        ],
      );
}
