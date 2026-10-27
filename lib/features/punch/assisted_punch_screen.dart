import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'assisted_punch_controller.dart';

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class AssistedPunchScreen extends ConsumerStatefulWidget {
  const AssistedPunchScreen({super.key});

  @override
  ConsumerState<AssistedPunchScreen> createState() =>
      _AssistedPunchScreenState();
}

class _AssistedPunchScreenState extends ConsumerState<AssistedPunchScreen> {
  final _number = TextEditingController();

  @override
  void initState() {
    super.initState();
    // chaque ouverture repart d'une nouvelle tentative
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(assistedPunchControllerProvider.notifier).reset(),
    );
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final c = ref.read(assistedPunchControllerProvider.notifier);
    try {
      final picked = await ref.read(selfiePickerProvider)();
      if (picked == null || !mounted) return;
      c.setSelfie(picked.$1, picked.$2);
    } catch (_) {
      if (mounted) c.selfieFailed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(assistedPunchControllerProvider);
    final c = ref.read(assistedPunchControllerProvider.notifier);
    final text = Theme.of(context).textTheme;

    final List<Widget> body;
    switch (s.step) {
      case AssistedStep.enterNumber:
      case AssistedStep.error when s.colleague == null:
        body = [
          Text('Matricule du collègue', style: text.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _number,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Matricule',
              border: OutlineInputBorder(),
            ),
            onSubmitted: c.lookup,
          ),
          if (s.error != null) ...[
            const SizedBox(height: 12),
            Text(s.error!, style: const TextStyle(color: AppColors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => c.lookup(_number.text),
            child: const Text('Vérifier'),
          ),
        ];
      case AssistedStep.confirm:
        body = [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(s.colleague!.displayName),
              subtitle: Text(s.colleague!.employeeNumber),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: c.confirm, child: const Text("C'est moi")),
          const SizedBox(height: 8),
          TextButton(onPressed: c.reset, child: const Text('Modifier')),
        ];
      case AssistedStep.selfie:
      case AssistedStep.sending:
      case AssistedStep.error:
        final sending = s.step == AssistedStep.sending;
        body = [
          Text(s.colleague!.displayName, style: text.titleMedium),
          const SizedBox(height: 12),
          if (s.photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                Uint8List.fromList(s.photo!),
                height: 280,
                fit: BoxFit.cover,
              ),
            ),
          if (s.error != null) ...[
            const SizedBox(height: 12),
            Text(s.error!, style: const TextStyle(color: AppColors.red)),
          ],
          const SizedBox(height: 16),
          if (sending)
            const Center(child: CircularProgressIndicator())
          else if (s.photo == null)
            FilledButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Prendre le selfie'),
            )
          else ...[
            FilledButton(
              onPressed: s.photo == null ? null : c.send,
              child: const Text('Pointer'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _pick, child: const Text('Reprendre')),
          ],
        ];
      case AssistedStep.done:
        final e = s.entry!;
        body = [
          const Icon(Icons.hourglass_top, size: 64, color: AppColors.yellow),
          const SizedBox(height: 16),
          Text(
            'Pointage enregistré pour ${s.colleague!.displayName} — en attente de validation',
            style: text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${e.isIn ? 'Entrée' : 'Sortie'} à ${_hm(e.occurredAt)}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              c.reset();
              Navigator.of(context).pop();
            },
            child: const Text('Terminer'),
          ),
        ];
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pointer pour un collègue')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: body),
      ),
    );
  }
}
