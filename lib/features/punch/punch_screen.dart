import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../auth/session_provider.dart';
import 'punch_controller.dart';
import 'punch_repository.dart';

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
String _date(DateTime t) => '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';

class PunchScreen extends ConsumerWidget {
  const PunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(punchControllerProvider, (prev, next) {
      if (prev?.loading != true || next.loading) return;
      final messenger = ScaffoldMessenger.of(context);
      if (next.error != null) {
        HapticFeedback.heavyImpact();
        messenger.showSnackBar(SnackBar(backgroundColor: AppColors.red, content: Text(next.error!)));
      } else if (next.last case final e?) {
        HapticFeedback.mediumImpact();
        messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.green,
          content: Text('${e.isIn ? 'Arrivée' : 'Départ'} enregistré à ${_hm(e.occurredAt)}'),
        ));
      }
    });

    final punch = ref.watch(punchControllerProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const FlagStripe(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(children: [
              const Icon(Icons.badge_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(ref.watch(sessionProvider).value?.employeeNumber ?? '', style: text.titleMedium)),
              IconButton(
                tooltip: 'Se déconnecter',
                icon: const Icon(Icons.logout),
                onPressed: () => ref.read(sessionProvider.notifier).logout(),
              ),
            ]),
          ),
          const Spacer(),
          Text(_hm(now), style: text.displayLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 72)),
          Text(_date(now), style: text.titleMedium?.copyWith(color: text.bodySmall?.color)),
          const SizedBox(height: 24),
          _StatusBadge(entry: punch.last),
          const Spacer(),
          _PunchButton(loading: punch.loading, onTap: () => ref.read(punchControllerProvider.notifier).punch()),
          const Spacer(),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.entry});
  final TimeEntry? entry;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (entry) {
      null => (AppColors.yellow, 'Pas encore pointé'),
      final e when e.isIn => (AppColors.green, 'En service depuis ${_hm(e.occurredAt)}'),
      final e => (AppColors.red, 'Sorti à ${_hm(e.occurredAt)}'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _PunchButton extends StatelessWidget {
  const _PunchButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pointer',
      child: AnimatedScale(
        scale: loading ? 0.95 : 1,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: AppColors.green,
          shape: const CircleBorder(),
          elevation: 8,
          shadowColor: AppColors.green.withValues(alpha: 0.5),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: loading ? null : onTap,
            child: SizedBox.square(
              dimension: 200,
              child: Center(
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                    : const Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.fingerprint, size: 64, color: Colors.white),
                        SizedBox(height: 8),
                        Text('POINTER', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
