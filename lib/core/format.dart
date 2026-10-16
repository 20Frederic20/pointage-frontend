String _two(int n) => n.toString().padLeft(2, '0');

/// `jj/mm/aaaa`, ou un tiret quand la date est absente.
String formatDate(DateTime? d) => d == null ? '—' : '${_two(d.day)}/${_two(d.month)}/${d.year}';
