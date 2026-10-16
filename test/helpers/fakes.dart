import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/paged.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/auth/session_provider.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/directory/directory_model.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/user/user_model.dart';
import 'package:pointage/features/user/user_repository.dart';

/// Session ouverte sans stockage sécurisé ni réseau.
class FakeSession extends SessionNotifier {
  FakeSession({this.token = 'tok'});
  final String? token;

  @override
  Future<Session?> build() async => Session(
        accessToken: token ?? '',
        refreshToken: 'refresh',
        accessExpiresAt: DateTime(2100),
        identifier: 'EMP0000001',
      );

  @override
  Future<String?> accessToken() async => token;

  @override
  Future<void> logout() async => state = const AsyncData(null);
}

Override fakeSession({String? token = 'tok'}) => sessionProvider.overrideWith(() => FakeSession(token: token));

Employee fakeEmployee(int n, {Role role = Role.employee, bool isActive = true}) => Employee(
      id: 'emp$n',
      userId: 'usr$n',
      employeeNumber: 'EMP${n.toString().padLeft(7, '0')}',
      role: role,
      isActive: isActive,
      phone: '0102030405',
      createdAt: DateTime(2026, 1, n % 28 + 1),
    );

typedef ListCall = ({EmployeeFilters filters, int limit, int offset});

/// Repository en mémoire qui filtre comme le backend (matricule exact).
class FakeEmployeeRepository implements EmployeeRepository {
  FakeEmployeeRepository([List<Employee>? all]) : all = all ?? [for (var n = 1; n <= 45; n++) fakeEmployee(n)];

  final List<Employee> all;
  final List<ListCall> calls = [];
  Object? listError;
  Object? createError;
  EmployeeDraft? lastDraft;

  /// Appelée avant chaque réponse de [list] avec le numéro de l'appel : permet de retenir une réponse.
  Future<void> Function(int call)? beforeReturn;

  @override
  Future<Paged<Employee>> list(String accessToken,
      {EmployeeFilters filters = const EmployeeFilters(), int limit = 20, int offset = 0}) async {
    final call = calls.length;
    calls.add((filters: filters, limit: limit, offset: offset));
    await beforeReturn?.call(call);
    if (listError case final error?) throw error;
    final matching = all
        .where((e) =>
            (filters.search.isEmpty || e.employeeNumber == filters.search) &&
            (filters.role == null || e.role == filters.role) &&
            (filters.isActive == null || e.isActive == filters.isActive))
        .toList();
    return Paged(items: matching.skip(offset).take(limit).toList(), total: matching.length);
  }

  @override
  Future<Employee> getById(String accessToken, String id) async =>
      all.firstWhere((e) => e.id == id, orElse: () => throw ApiException('Élément introuvable.', status: 404));

  @override
  Future<Employee> create(String accessToken, EmployeeDraft draft) async {
    lastDraft = draft;
    if (createError case final error?) throw error;
    final created = Employee(
      id: 'emp${all.length + 1}',
      userId: draft.userId,
      employeeNumber: draft.employeeNumber,
      role: draft.role,
      isActive: draft.isActive,
      phone: draft.phone,
    );
    all.add(created);
    return created;
  }
}

const ana = AppUser(
    id: 'usr1', email: 'ana@pointage.bj', role: Role.employee, isActive: true, firstName: 'Ana', lastName: 'Dossou');
const direction = Directory(id: 'dir1', name: 'Direction générale', code: 'DG');
const siege = Site(id: 'sit1', name: 'Siège Cotonou');

class FakeUserRepository implements UserRepository {
  FakeUserRepository({this.users = const [ana], this.error});
  final List<AppUser> users;
  Object? error;

  @override
  Future<Paged<AppUser>> list(String accessToken, {int limit = 100, int offset = 0}) async {
    if (error case final e?) throw e;
    return Paged(items: users, total: users.length);
  }
}

class FakeDirectoryRepository implements DirectoryRepository {
  FakeDirectoryRepository({this.directories = const [direction], this.sitesByDirectory = const {'dir1': [siege]}, this.error});
  final List<Directory> directories;
  final Map<String, List<Site>> sitesByDirectory;
  Object? error;

  @override
  Future<Paged<Directory>> list(String accessToken, {int limit = 100, int offset = 0}) async {
    if (error case final e?) throw e;
    return Paged(items: directories, total: directories.length);
  }

  @override
  Future<List<Site>> sites(String accessToken, String directoryId) async => sitesByDirectory[directoryId] ?? const [];
}
