import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../auth/session_provider.dart';
import '../employee_model.dart';
import '../employee_repository.dart';

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// « Faire pointer » : confirmation, puis pointage au nom de [employee]. Absent pour un employé inactif.
/// [labeled] affiche un bouton avec texte (fiche) au lieu d'une icône (tableau, liste).
class PunchForEmployeeButton extends ConsumerStatefulWidget {
  const PunchForEmployeeButton({super.key, required this.employee, this.labeled = false});
  final Employee employee;
  final bool labeled;

  @override
  ConsumerState<PunchForEmployeeButton> createState() => _PunchForEmployeeButtonState();
}

class _PunchForEmployeeButtonState extends ConsumerState<PunchForEmployeeButton> {
  bool _busy = false;

  Future<void> _punch() async {
    if (_busy) return;
    setState(() => _busy = true); // aussi pendant la boîte de dialogue : pas de second dialogue
    final number = widget.employee.employeeNumber;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmDialog(number: number),
      );
      if (confirmed != true) return;
      final token = await ref.read(sessionProvider.notifier).accessToken();
      if (token == null) throw ApiException('Session expirée, reconnectez-vous.', status: 401);
      final entry = await ref.read(employeeRepositoryProvider).punchFor(token, widget.employee.id);
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.green,
        content: Text('${entry.isIn ? 'Entrée' : 'Sortie'} enregistrée pour $number à ${_hm(entry.occurredAt)}'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.red,
        content: Text(e is ApiException ? e.message : 'Connexion au serveur impossible, réessayez.'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.employee.isActive) return const SizedBox.shrink();
    final onPressed = _busy ? null : _punch;
    return widget.labeled
        ? FilledButton.tonalIcon(onPressed: onPressed, icon: const Icon(Icons.fingerprint), label: const Text('Faire pointer'))
        : IconButton(tooltip: 'Faire pointer', icon: const Icon(Icons.fingerprint), onPressed: onPressed);
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.number});
  final String number;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _done = false;

  /// Un double appui ne ferme qu'une fois (un second pop fermerait la page dessous).
  void _close(bool value) {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Faire pointer ${widget.number} maintenant ?'),
        actions: [
          TextButton(onPressed: () => _close(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => _close(true), child: const Text('Faire pointer')),
        ],
      );
}
