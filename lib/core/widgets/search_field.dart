import 'dart:async';

import 'package:flutter/material.dart';

/// Champ de recherche : envoie le texte (sans espaces autour) après [debounce] sans frappe,
/// ou tout de suite à la validation.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialValue = '',
    this.debounce = const Duration(milliseconds: 300),
  });

  final String label;
  final ValueChanged<String> onChanged;
  final String initialValue;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // widget.onChanged est lu au déclenchement : c'est toujours le callback le plus récent.
  void _changed(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value.trim()));
  }

  void _submitted(String value) {
    _timer?.cancel();
    widget.onChanged(value.trim());
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        onChanged: _changed,
        onSubmitted: _submitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(labelText: widget.label, isDense: true, prefixIcon: const Icon(Icons.search)),
      );
}
