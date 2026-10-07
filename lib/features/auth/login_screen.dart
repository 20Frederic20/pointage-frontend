import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'auth_repository.dart';
import 'session_provider.dart';

/// Connexion : matricule OU email, puis code reçu par email (6 chiffres).
/// Les comptes qui ont un mot de passe passent par « Se connecter avec un mot de passe ».
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController(); // matricule ou email
  final _secret = TextEditingController(); // code ou mot de passe

  bool _usePassword = false;
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _identifier.dispose();
    _secret.dispose();
    super.dispose();
  }

  String get _identifierValue => _identifier.text.trim();

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Connexion au serveur impossible.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.red, content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
        await ref.read(authRepositoryProvider).requestCode(_identifierValue);
        if (!mounted) return;
        setState(() {
          _codeSent = true;
          _secret.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Si ce compte existe, un code vient d'être envoyé à son adresse email.")),
        );
      });

  Future<void> _signIn() => _run(() async {
        final repo = ref.read(authRepositoryProvider);
        final tokens = _usePassword
            ? await repo.loginWithPassword(_identifierValue, _secret.text)
            : await repo.verifyCode(_identifierValue, _secret.text.trim());
        await ref.read(sessionProvider.notifier).signIn(tokens, _identifierValue);
      });

  void _toggleMode() => setState(() {
        _usePassword = !_usePassword;
        _codeSent = false;
        _secret.clear();
      });

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final showSecret = _usePassword || _codeSent;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const FlagStripe(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.fingerprint, size: 72, color: AppColors.green),
                        const SizedBox(height: 16),
                        Text('Pointage',
                            textAlign: TextAlign.center,
                            style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _identifier,
                          enabled: !_codeSent,
                          validator: _required,
                          autocorrect: false,
                          keyboardType: TextInputType.emailAddress, // garde chiffres, lettres et @ à portée
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          textInputAction: showSecret ? TextInputAction.next : TextInputAction.done,
                          onFieldSubmitted: (_) => showSecret ? null : _sendCode(),
                          decoration: const InputDecoration(
                            labelText: 'Matricule ou email',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        if (showSecret) ...[
                          const SizedBox(height: 16),
                          _usePassword
                              ? TextFormField(
                                  controller: _secret,
                                  obscureText: true,
                                  validator: _required,
                                  autofillHints: const [AutofillHints.password],
                                  onFieldSubmitted: (_) => _signIn(),
                                  decoration: const InputDecoration(
                                      labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock_outline)),
                                )
                              : TextFormField(
                                  controller: _secret,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  autofillHints: const [AutofillHints.oneTimeCode],
                                  validator: (v) => (v == null || v.length != 6) ? 'Le code a 6 chiffres' : null,
                                  onFieldSubmitted: (_) => _signIn(),
                                  style: text.headlineSmall?.copyWith(letterSpacing: 8),
                                  decoration: const InputDecoration(
                                    labelText: 'Code reçu par email',
                                    helperText: 'Valable 10 minutes',
                                    prefixIcon: Icon(Icons.pin_outlined),
                                  ),
                                ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy ? null : (showSecret ? _signIn : _sendCode),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : Text(showSecret ? 'Se connecter' : 'Recevoir un code'),
                        ),
                        if (_codeSent)
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            TextButton(
                              onPressed: _busy ? null : () => setState(() => _codeSent = false),
                              child: const Text("Changer d'identifiant"),
                            ),
                            TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Renvoyer le code')),
                          ]),
                        TextButton(
                          onPressed: _busy ? null : _toggleMode,
                          child: Text(_usePassword ? 'Recevoir un code par email' : 'Se connecter avec un mot de passe'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
