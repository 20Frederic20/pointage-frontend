import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../anomaly_controller.dart';
import '../anomaly_model.dart';

/// Contenu du détail, partagé par le panneau (grand écran) et la page (petit écran).
/// [onDecided] est appelé après une décision réussie.
class AnomalyDetailView extends ConsumerStatefulWidget {
  const AnomalyDetailView({super.key, required this.anomaly, this.onDecided});
  final Anomaly anomaly;
  final VoidCallback? onDecided;

  @override
  ConsumerState<AnomalyDetailView> createState() => _AnomalyDetailViewState();
}

class _AnomalyDetailViewState extends ConsumerState<AnomalyDetailView> {
  bool _busy = false;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _decide(Future<String?> Function() action) async {
    // Lus avant l'await : la vue peut être fermée pendant la requête.
    final messenger = ScaffoldMessenger.of(context);
    final onDecided = widget.onDecided;
    setState(() => _busy = true);
    final error = await action();
    if (mounted) setState(() => _busy = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.red, content: Text(error)));
    } else {
      onDecided?.call();
    }
  }

  Future<void> _validate() {
    final comment = _comment.text.trim();
    return _decide(() => ref
        .read(anomalyControllerProvider.notifier)
        .validate(widget.anomaly.id, comment: comment.isEmpty ? null : comment));
  }

  Future<void> _reject() async {
    final comment = await showDialog<String>(context: context, builder: (_) => const RejectDialog());
    if (comment == null || !mounted) return;
    await _decide(() => ref.read(anomalyControllerProvider.notifier).reject(widget.anomaly.id, comment));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.anomaly;
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(a.employeeName.isEmpty ? 'Employé inconnu' : a.employeeName,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      if (a.employeeNumber case final n?) Text(n, style: theme.textTheme.bodyMedium),
      const SizedBox(height: 16),
      _Selfie(anomaly: a),
      const SizedBox(height: 16),
      _Field(label: 'Site', value: a.siteName ?? '—'),
      _Field(label: 'Pointé depuis le téléphone de', value: a.assistedByName.isEmpty ? '—' : a.assistedByName),
      _Field(label: 'Date / heure', value: formatDateTime(a.occuredAt)),
      _Field(label: 'Entrée/Sortie', value: anomalyEntryTypeLabel(a.entryType)),
      _Field(label: 'Statut', value: anomalyStatusLabel(a.status)),
      if (!a.isOpen) ...[
        _Field(label: 'Décidée le', value: formatDateTime(a.decidedAt)),
        if (a.decisionComment case final c?) _Field(label: 'Commentaire', value: c),
      ],
      if (a.isOpen) ...[
        const Divider(height: 32),
        TextField(
          controller: _comment,
          maxLength: 512,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Commentaire (facultatif)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: _busy ? null : _validate,
            icon: const Icon(Icons.check),
            label: const Text('Valider'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _reject,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
            icon: const Icon(Icons.close),
            label: const Text('Rejeter'),
          ),
        ]),
      ],
    ]);
  }
}

class _Selfie extends ConsumerWidget {
  const _Selfie({required this.anomaly});
  final Anomaly anomaly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget placeholder(String text, {IconData icon = Icons.no_photography_outlined}) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48), const SizedBox(height: 8), Text(text)]));
    final Widget child = !anomaly.hasPhoto
        ? placeholder('Aucune photo')
        : switch (ref.watch(anomalyPhotoProvider(anomaly.id))) {
            AsyncData(:final value) => Image.memory(value, fit: BoxFit.contain, errorBuilder: (_, _, _) => placeholder('Photo illisible')),
            AsyncError() => placeholder('Photo indisponible', icon: Icons.broken_image_outlined),
            _ => const Center(child: CircularProgressIndicator()),
          };
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: text.labelMedium),
        Text(value, style: text.bodyLarge),
      ]),
    );
  }
}

/// Saisie du motif de rejet : « Rejeter » reste désactivé tant que le commentaire est vide.
/// Renvoie le commentaire (sans espaces autour) ou null si annulé.
class RejectDialog extends StatefulWidget {
  const RejectDialog({super.key});

  @override
  State<RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<RejectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Rejeter ce pointage'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 512,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Motif du rejet (obligatoire)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: _controller.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_controller.text.trim()),
            child: const Text('Rejeter'),
          ),
        ],
      );
}
