import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/work_time/period.dart';

void main() {
  final now = DateTime(2026, 11, 5, 14, 30); // un jeudi

  test('presets: today, yesterday, this week (Monday → today), this month', () {
    expect(Period.today(now: now).query, {'from': '2026-11-05', 'to': '2026-11-05'});
    expect(Period.yesterday(now: now).query, {'from': '2026-11-04', 'to': '2026-11-04'});
    expect(Period.thisWeek(now: now).query, {'from': '2026-11-02', 'to': '2026-11-05'});
    expect(Period.thisMonth(now: now).query, {'from': '2026-11-01', 'to': '2026-11-05'});
  });

  test('labels: preset names, else the two dates', () {
    expect(Period.today(now: now).labelAt(now), "Aujourd'hui");
    expect(Period.yesterday(now: now).labelAt(now), 'Hier');
    expect(Period.thisWeek(now: now).labelAt(now), 'Cette semaine');
    expect(Period.thisMonth(now: now).labelAt(now), 'Ce mois-ci');
    expect(Period(DateTime(2026, 10, 1), DateTime(2026, 10, 15)).labelAt(now), '01/10/2026 – 15/10/2026');
  });

  test('a period keeps only the days and compares by value', () {
    final p = Period(DateTime(2026, 10, 1, 9), DateTime(2026, 10, 2, 18));
    expect((p.from, p.to), (DateTime(2026, 10, 1), DateTime(2026, 10, 2)));
    expect(p, Period(DateTime(2026, 10, 1), DateTime(2026, 10, 2)));
  });
}
