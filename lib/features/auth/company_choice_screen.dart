import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'auth_repository.dart';

/// Fiches actives dans plusieurs entreprises : la personne choisit où elle se connecte.
class CompanyChoiceScreen extends StatefulWidget {
  const CompanyChoiceScreen({super.key, required this.employments, required this.onChoose});

  final List<Employment> employments;

  /// Ouvre la session sur la fiche choisie ; une [ApiException] s'affiche en bas de l'écran.
  final Future<void> Function(Employment) onChoose;

  @override
  State<CompanyChoiceScreen> createState() => _CompanyChoiceScreenState();
}

class _CompanyChoiceScreenState extends State<CompanyChoiceScreen> {
  bool _busy = false;

  Future<void> _choose(Employment employment) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onChoose(employment);
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Connexion au serveur impossible.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.red, content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Choix de l\'entreprise')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Text('Dans quelle entreprise voulez-vous vous connecter ?',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (_busy) const LinearProgressIndicator(),
                for (final e in widget.employments)
                  Card(
                    child: ListTile(
                      enabled: !_busy,
                      leading: const Icon(Icons.apartment_outlined),
                      title: Text(e.companyName ?? 'Entreprise inconnue'),
                      subtitle: Text(e.role.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _choose(e),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
}
