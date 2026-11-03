import 'package:flutter/material.dart';

/// Nom et code d'un annuaire (création ou modification). Renvoie null si annulé.
Future<({String name, String code})?> showDirectoryFormDialog(BuildContext context,
        {required String title, String name = '', String code = ''}) =>
    showDialog<({String name, String code})>(
      context: context,
      builder: (_) => _DirectoryFormDialog(title: title, name: name, code: code),
    );

class _DirectoryFormDialog extends StatefulWidget {
  const _DirectoryFormDialog({required this.title, required this.name, required this.code});
  final String title;
  final String name;
  final String code;

  @override
  State<_DirectoryFormDialog> createState() => _DirectoryFormDialogState();
}

class _DirectoryFormDialogState extends State<_DirectoryFormDialog> {
  late final _name = TextEditingController(text: widget.name);
  late final _code = TextEditingController(text: widget.code);

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _code.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nom'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Code'),
                onChanged: (_) => setState(() {}),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: _valid
                ? () => Navigator.of(context).pop((name: _name.text.trim(), code: _code.text.trim()))
                : null,
            child: const Text('Enregistrer'),
          ),
        ],
      );
}
