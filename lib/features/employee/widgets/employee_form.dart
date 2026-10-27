import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/role.dart';
import '../../../core/theme.dart';
import '../../directory/directory_controller.dart';
import '../employee_controller.dart';
import '../employee_model.dart';

/// Formulaire de création : le compte et l'employé en une fois.
/// Les règles reprennent celles du backend (`OnboardEmployeeRequest`).
class EmployeeForm extends ConsumerStatefulWidget {
  const EmployeeForm({super.key, required this.onCreated, this.title});

  final ValueChanged<Employee> onCreated;

  /// Titre affiché dans le dialogue (la page plein écran a déjà une AppBar).
  final String? title;

  @override
  ConsumerState<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends ConsumerState<EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _number = TextEditingController();
  final _phone = TextEditingController();
  String? _directoryId;
  String? _siteId;
  Role _role = Role.employee;
  bool _isActive = false;
  DateTime? _startDate;

  /// Erreur locale : une liste de choix n'a pas pu se charger.
  String? _missing;

  @override
  void dispose() {
    for (final c in [_email, _password, _firstName, _lastName]) {
      c.dispose();
    }
    _number.dispose();
    _phone.dispose();
    super.dispose();
  }

  static String? _length(String? v, {required bool required}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return required ? 'Champ obligatoire' : null;
    return s.length < 10 || s.length > 20 ? 'Entre 10 et 20 caractères' : null;
  }

  static String? _emailFormat(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Champ obligatoire';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s) ? null : 'Email invalide';
  }

  static String? _name(String? v) => (v?.trim() ?? '').isEmpty ? 'Champ obligatoire' : null;

  /// Facultatif ; s'il est saisi, 8 caractères au moins comme le backend.
  static String? _passwordLength(String? v) => v != null && v.isNotEmpty && v.length < 8 ? 'Au moins 8 caractères' : null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    // Une liste en échec n'est pas un champ de formulaire : on la vérifie à part.
    setState(() => _missing = _directoryId == null ? 'Choisissez un annuaire.' : null);
    if (!valid || _missing != null) return;
    final phone = _phone.text.trim();
    final created = await ref.read(employeeFormControllerProvider.notifier).submit(EmployeeDraft(
          email: _email.text.trim(),
          password: _password.text.isEmpty ? null : _password.text,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          directoryId: _directoryId!,
          employeeNumber: _number.text.trim(),
          role: _role,
          phone: phone.isEmpty ? null : phone,
          isActive: _isActive,
          siteId: _siteId,
          assignmentStartDate: _startDate,
        ));
    if (created != null && mounted) widget.onCreated(created);
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(employeeFormControllerProvider);
    final error = _missing ?? form.error;
    final directoryId = _directoryId;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (widget.title case final title?) ...[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
          ],
          const _Section('Compte'),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: _emailFormat,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstName,
            decoration: const InputDecoration(labelText: 'Prénom'),
            validator: _name,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastName,
            decoration: const InputDecoration(labelText: 'Nom'),
            validator: _name,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mot de passe (facultatif)',
              helperText: 'Sans mot de passe, connexion par code reçu par email',
            ),
            validator: _passwordLength,
          ),
          const SizedBox(height: 24),
          const _Section('Poste'),
          _OptionsField(
            label: 'Annuaire',
            options: ref
                .watch(allDirectoriesProvider)
                .whenData((directories) => {for (final d in directories) d.id: '${d.name} (${d.code})'}),
            value: _directoryId,
            onRetry: () => ref.invalidate(allDirectoriesProvider),
            onChanged: (v) => setState(() {
              _directoryId = v;
              _siteId = null;
            }),
          ),
          const SizedBox(height: 16),
          if (directoryId == null)
            const TextField(
              enabled: false,
              decoration: InputDecoration(labelText: 'Site (facultatif)', hintText: "Choisissez d'abord un annuaire"),
            )
          else
            _OptionsField(
              key: ValueKey(directoryId),
              label: 'Site (facultatif)',
              emptyLabel: 'Site principal',
              options: ref
                  .watch(directorySitesProvider(directoryId))
                  .whenData((sites) => {for (final s in sites) s.id: s.name}),
              value: _siteId,
              onRetry: () => ref.invalidate(directorySitesProvider(directoryId)),
              onChanged: (v) => setState(() => _siteId = v),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _number,
            decoration: const InputDecoration(labelText: 'Matricule'),
            validator: (v) => _length(v, required: true),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Role>(
            initialValue: _role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Rôle'),
            items: [for (final r in Role.values) DropdownMenuItem(value: r, child: Text(r.label))],
            onChanged: (r) => setState(() => _role = r ?? Role.employee),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone (facultatif)'),
            validator: (v) => _length(v, required: false),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Actif'),
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text("Début d'affectation"),
            subtitle: Text(_startDate == null ? "Aujourd'hui (par défaut)" : formatDate(_startDate)),
            onTap: _pickDate,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error, style: const TextStyle(color: AppColors.red)),
            ),
          const SizedBox(height: 24),
          Wrap(alignment: WrapAlignment.end, spacing: 12, runSpacing: 8, children: [
            TextButton(
              onPressed: form.submitting ? null : () => Navigator.of(context).maybePop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: form.submitting ? null : _submit,
              child: form.submitting
                  ? const SizedBox.square(
                      dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Créer'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.green)),
      );
}

/// Liste déroulante alimentée par le backend (id → libellé), avec chargement et nouvel essai.
/// Sans [emptyLabel], le choix est obligatoire.
class _OptionsField extends StatelessWidget {
  const _OptionsField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.onRetry,
    this.emptyLabel,
  });

  final String label;
  final AsyncValue<Map<String, String>> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRetry;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) => switch (options) {
        AsyncData(value: final items) => DropdownButtonFormField<String?>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: label,
              helperText: items.isEmpty ? 'Aucun élément disponible' : null,
            ),
            items: [
              if (emptyLabel != null) DropdownMenuItem<String?>(value: null, child: Text(emptyLabel!)),
              for (final MapEntry(:key, value: text) in items.entries)
                DropdownMenuItem<String?>(value: key, child: Text(text, overflow: TextOverflow.ellipsis)),
            ],
            validator: emptyLabel == null ? (v) => v == null ? 'Champ obligatoire' : null : null,
            onChanged: onChanged,
          ),
        AsyncError() => InputDecorator(
            decoration: InputDecoration(labelText: label, errorText: 'Chargement impossible'),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
            ),
          ),
        _ => InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: const LinearProgressIndicator(),
          ),
      };
}
