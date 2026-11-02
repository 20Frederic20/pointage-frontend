String _two(int n) => n.toString().padLeft(2, '0');

/// `jj/mm/aaaa`, ou un tiret quand la date est absente.
String formatDate(DateTime? d) => d == null ? '—' : '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// `jj/mm/aaaa hh:mm`, ou un tiret quand la date est absente.
String formatDateTime(DateTime? d) => d == null ? '—' : '${formatDate(d)} ${_two(d.hour)}:${_two(d.minute)}';

/// `hh:mm` d'un instant, ou un tiret quand il est absent.
String formatTime(DateTime? d) => d == null ? '—' : '${_two(d.hour)}:${_two(d.minute)}';

/// Durée en `h:mm` (les heures peuvent dépasser 24).
String formatDuration(Duration d) => '${d.inMinutes ~/ 60}:${_two(d.inMinutes % 60)}';
