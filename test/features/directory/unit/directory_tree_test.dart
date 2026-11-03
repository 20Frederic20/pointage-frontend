import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/directory/directory_model.dart';
import 'package:pointage/features/directory/directory_tree.dart';

const _companyB = Directory(id: 'b', name: 'Société B', code: 'SB');
const _companyA = Directory(id: 'a', name: 'Société A', code: 'SA');
const _nord = Directory(id: 'n', name: 'Agence Nord', code: 'SA-N', parentDirectoryId: 'a');
const _est = Directory(id: 'e', name: 'Agence Est', code: 'SA-E', parentDirectoryId: 'a');
const _guichet = Directory(id: 'g', name: 'Guichet', code: 'SA-N-G', parentDirectoryId: 'n');
const _siege = Site(id: 's1', name: 'Siège A', directoryId: 'a', isPrincipal: true);
const _annexe = Site(id: 's2', name: 'Annexe Nord', directoryId: 'n');

void main() {
  test('companies are roots sorted by name, services nested and sorted, sites attached', () {
    final tree = buildDirectoryTree([_companyB, _nord, _companyA, _est, _guichet], {
      'a': [_siege],
      'n': [_annexe],
    });
    expect(tree.map((n) => n.directory.name), ['Société A', 'Société B']);
    final a = tree.first;
    expect(a.children.map((n) => n.directory.name), ['Agence Est', 'Agence Nord']);
    expect(a.sites.single.name, 'Siège A');
    expect(a.children.last.children.single.directory.name, 'Guichet');
    expect(a.children.last.sites.single.name, 'Annexe Nord');
  });

  test('a deactivated company blocks its services and their sites, not itself twice', () {
    final tree = buildDirectoryTree([_companyA.copyWith(active: false), _nord, _guichet], {'n': [_annexe]});
    final a = tree.single;
    final nord = a.children.single;
    expect((a.blocked, nord.blocked, nord.children.single.blocked), (true, true, true));
    expect(nord.blockedBy?.name, 'Société A');
    expect(a.blockedBy, isNull); // blocked by itself
    expect(isSiteBlocked(_annexe, nord), isTrue);
  });

  test('an inactive site is blocked under an active directory', () {
    final tree = buildDirectoryTree([_companyA], {'a': [_siege.copyWith(active: false)]});
    expect(tree.single.blocked, isFalse);
    expect(isSiteBlocked(tree.single.sites.single, tree.single), isTrue);
    expect(isSiteBlocked(_siege, tree.single), isFalse);
  });

  test('a directory whose parent is unknown is shown as a root', () {
    final tree = buildDirectoryTree([const Directory(id: 'x', name: 'Orphelin', code: 'X', parentDirectoryId: 'zz')], {});
    expect(tree.single.directory.name, 'Orphelin');
  });

  test('findNode finds a directory anywhere in the tree', () {
    final tree = buildDirectoryTree([_companyA, _nord, _guichet], {});
    expect(findNode(tree, 'g')?.directory.name, 'Guichet');
    expect(findNode(tree, 'nope'), isNull);
  });

  test('assignableDirectories drops a deactivated directory and everything under it', () {
    final all = [_companyA.copyWith(active: false), _nord, _guichet, _companyB, _est.copyWith(active: false)];
    expect(assignableDirectories(all).map((d) => d.id), ['b']);
    expect(assignableDirectories([_companyA, _nord, _guichet]).map((d) => d.id), ['a', 'n', 'g']);
  });

  test('assignableSites keeps the active sites only', () {
    expect(assignableSites([_siege, _annexe.copyWith(active: false)]).map((s) => s.id), ['s1']);
  });
}
