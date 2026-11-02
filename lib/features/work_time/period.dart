import '../../core/format.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Une période de jours, bornes incluses (le backend la limite à 62 jours).
class Period {
  Period(DateTime from, DateTime to)
      : from = _day(from),
        to = _day(to);

  final DateTime from;
  final DateTime to;

  factory Period.today({DateTime? now}) {
    final d = now ?? DateTime.now();
    return Period(d, d);
  }

  factory Period.yesterday({DateTime? now}) {
    final d = _day(now ?? DateTime.now()).subtract(const Duration(days: 1));
    return Period(d, d);
  }

  /// Du lundi à aujourd'hui.
  factory Period.thisWeek({DateTime? now}) {
    final d = _day(now ?? DateTime.now());
    return Period(d.subtract(Duration(days: d.weekday - DateTime.monday)), d);
  }

  /// Du 1er du mois à aujourd'hui.
  factory Period.thisMonth({DateTime? now}) {
    final d = _day(now ?? DateTime.now());
    return Period(DateTime(d.year, d.month), d);
  }

  /// Paramètres `from` / `to` des routes du backend.
  Map<String, String> get query => {'from': _iso(from), 'to': _iso(to)};

  String get label => labelAt(DateTime.now());

  /// Nom du préréglage correspondant (par rapport à [now]), sinon les deux dates.
  String labelAt(DateTime now) {
    if (this == Period.today(now: now)) return "Aujourd'hui";
    if (this == Period.yesterday(now: now)) return 'Hier';
    if (this == Period.thisWeek(now: now)) return 'Cette semaine';
    if (this == Period.thisMonth(now: now)) return 'Ce mois-ci';
    return '${formatDate(from)} – ${formatDate(to)}';
  }

  @override
  bool operator ==(Object other) => other is Period && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}
