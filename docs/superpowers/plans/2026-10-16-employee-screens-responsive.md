# Écrans Employés (web + mobile) et coquille admin adaptative — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** livrer un écran Employés web (adaptatif, dans une coquille admin réutilisable par tous les futurs menus) et un écran Employés mobile, sur un controller partagé, avec les routes backend manquantes.

**Architecture :** chaque module frontend suit `model → repository → controller (partagé) → screens/<x>_web_screen.dart + screens/<x>_mobile_screen.dart`. `AdminShell` (web) et `MobileShell` (mobile) sont génériques et reçoivent une liste de `NavItem` définie dans le point d'entrée (`main_admin.dart` / `main.dart`). Côté backend, on suit le chemin existant : query → handler → enregistrement dans `UsersContainer` → route FastAPI.

**Tech Stack :** Flutter 3.44 / Dart 3.12, flutter_riverpod 3.4.3, http 1.6 (`MockClient` pour les tests) ; FastAPI, python-cqrs, pytest (`uv run pytest`).

**Spec :** `docs/superpowers/specs/2026-10-16-employee-screens-responsive-design.md`

## Global Constraints

- Deux dépôts git distincts : frontend `/var/www/workspace/Pointage/frontend`, backend `/var/www/workspace/Pointage/backend`. Chaque commit va dans le dépôt des fichiers modifiés.
- Backend : ne jamais toucher ni stager `src/identity/infrastructure/importer.py` (modification non commitée qui n'est pas la nôtre) → toujours `git add <fichiers précis>`.
- Backend : un test échoue déjà avant ce travail (`tests/test_sites.py::test_punch_on_a_deactivated_site_is_refused`). Il reste hors périmètre ; aucune autre régression tolérée.
- Aucune nouvelle dépendance (frontend ni backend). `flutter_test` (SDK) et `package:http/testing.dart` (inclus dans `http`) suffisent.
- Frontend : imports relatifs dans `lib/` ; `package:pointage/...` dans `test/`.
- Couleurs via `AppColors` / `Theme` ; transparence via `withValues(alpha:)`, jamais `withOpacity`.
- Aucune largeur codée en dur dans les écrans : décisions de mise en page via `Breakpoints` (compact < 600 ≤ medium < 1024 ≤ expanded).
- Tailles de test de responsivité : **360, 800 et 1440 px** de large.
- Pagination : 20 éléments par page (`EmployeeState.limit`).
- Matricule : 10 à 20 caractères ; téléphone facultatif, 10 à 20 caractères (règles du backend).
- Le corps de `POST /employees` est en **snake_case** (`user_id`, `directory_id`, …) : `CreateEmployeeRequest` n'a pas d'alias camelCase. Les réponses sont en camelCase.
- Pas de contrôle d'accès par rôle dans ce travail (accès ouvert à tous les profils pour les tests).
- Tests rangés **par module puis par type** : backend `tests/identity/{unit,api}/`, frontend `test/core/{unit,widget}/`, `test/features/<module>/{unit,widget}/`, `test/helpers/`. Noms de fichiers de test backend uniques (mode d'import pytest par défaut).
- `flutter analyze` sans aucun avertissement à la fin de chaque tâche frontend.

## Review Focus

1. Changements de filtres rapides : une réponse ancienne qui arrive après une plus récente ne doit pas écraser la liste (compteur de génération dans `EmployeeController`, test dans Task 6).
2. Page courante qui n'existe plus après un rafraîchissement (le total a baissé) : on revient à la dernière page au lieu d'afficher une page vide (Task 6).
3. Mobile : une erreur pendant `loadMore` ne doit pas relancer le chargement en boucle, et une liste trop courte pour remplir l'écran doit quand même charger la suite (Task 12).
4. Admin avec **un seul menu** à largeur moyenne : `NavigationRail` exige au moins 2 destinations, d'où un rail maison (test dans Task 8).
5. Formulaire soumis alors que la liste des utilisateurs ou des annuaires n'a pas pu se charger : pas de crash sur un id null (Task 10).

---

## Structure des fichiers

**Backend (`/var/www/workspace/Pointage/backend`)**

| Fichier | Rôle |
|---|---|
| `src/identity/application/handlers/get_employee_by_id_handler.py` (créer) | Charge un employé, `None` si inconnu ou id mal formé |
| `src/identity/application/queries/get_directories.py` (créer) | Query paginée des annuaires |
| `src/identity/application/handlers/get_directories_handler.py` (créer) | Handler correspondant |
| `src/identity/application/dtos/user_dtos.py` (modifier) | `DirectoriesPageDTO` |
| `src/identity/application/handlers/get_users_handler.py` (modifier) | Correction `spec = None` |
| `src/identity/domain/repositories/{user,directory}_repository.py` (modifier) | Signatures `find`/`count` |
| `src/identity/infrastructure/persistence/{user,directory,event_sourced_directory}_repository.py` (modifier) | `find`/`count` sans filtre, tri stable |
| `src/identity/infrastructure/container.py` (modifier) | Enregistrement des 2 nouveaux handlers |
| `src/identity/interface/routers/{employees,users,directories}_router.py` (modifier) | Routes GET |
| `src/identity/interface/schemas.py` (modifier) | `DirectoryListResponse` |
| `tests/identity/conftest.py` (créer) | Faux repositories en mémoire, fabriques, client API |
| `tests/identity/unit/*.py`, `tests/identity/api/*.py` (créer) | Tests |

**Frontend (`/var/www/workspace/Pointage/frontend`)**

| Fichier | Rôle |
|---|---|
| `lib/core/api_client.dart` (modifier) | Gestion d'erreur unique, paramètres d'URL, messages FR |
| `lib/core/paged.dart` | `Paged<T>` (`Page` est déjà pris par Flutter) |
| `lib/core/role.dart` | Enum `Role` (5 valeurs + libellés) |
| `lib/core/format.dart` | `formatDate` |
| `lib/core/layout/breakpoints.dart` | `WindowSize`, `Breakpoints` |
| `lib/core/layout/nav_item.dart` | `NavItem(label, icon, builder)` |
| `lib/core/layout/admin_shell.dart` | Coquille web adaptative |
| `lib/core/layout/mobile_shell.dart` | Barre du bas mobile |
| `lib/core/widgets/state_views.dart` | `EmptyState`, `ErrorState` |
| `lib/core/widgets/pagination_bar.dart` | `PaginationBar` |
| `lib/core/widgets/search_field.dart` | Champ de recherche avec délai de 300 ms |
| `lib/features/auth/session_provider.dart` (modifier) | `requireAccessToken(ref)` |
| `lib/features/employee/employee_model.dart` (réécrire) | `Employee`, `EmployeeFilters`, `EmployeeDraft` |
| `lib/features/employee/employee_repository.dart` (réécrire) | `list` / `getById` / `create` |
| `lib/features/employee/employee_controller.dart` (réécrire) | Liste, détail, formulaire |
| `lib/features/employee/widgets/*.dart` | Badges, carte, tableau, filtres, barre d'outils, détail, formulaire |
| `lib/features/employee/screens/*.dart` | Web, mobile, page détail, page/dialogue de création |
| `lib/features/user/{user_model,user_repository,user_controller}.dart` | Comptes pour le sélecteur |
| `lib/features/directory/{directory_model,directory_repository,directory_controller}.dart` | Annuaires et sites pour les sélecteurs |
| `lib/features/punch/screens/punch_mobile_screen.dart` (déplacé) | Ancien `punch_screen.dart` |
| `lib/main.dart`, `lib/main_admin.dart` (modifier) | Composition des onglets / menus |
| `lib/features/employee/employee_screen.dart` (supprimer) | Remplacé |
| `test/...` | Voir chaque tâche |

---

## Partie A — Backend

### Task 1 : `GET /employees/{id}` (+ socle de tests identity)

**Files :**
- Create: `backend/tests/identity/conftest.py`
- Create: `backend/tests/identity/unit/test_get_employee_by_id_handler.py`
- Create: `backend/tests/identity/api/test_employees_api.py`
- Create: `backend/src/identity/application/handlers/get_employee_by_id_handler.py`
- Modify: `backend/src/identity/application/handlers/__init__.py`, `backend/src/identity/application/__init__.py`
- Modify: `backend/src/identity/infrastructure/container.py`
- Modify: `backend/src/identity/interface/routers/employees_router.py`

**Interfaces :**
- Produces : fixtures pytest `run`, `in_memory`, `make_employee`, `make_user`, `make_directory`, `identity_api` (attributs `client`, `employees`, `users`, `directories`) ; `GetEmployeeByIdHandler(employee_repository=...)` ; route `GET /employees/{employee_id}` → `EmployeeResponse` ou 404.

- [ ] **Step 1 : écrire le socle de tests** — `tests/identity/conftest.py`

```python
"""Shared fixtures for the identity tests: in-memory read side, factories,
and a TestClient over the real routers and the real UsersContainer wiring."""

import asyncio
from types import SimpleNamespace

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from core.domain.errors import NotFoundError
from core.exceptions import register_exception_handlers
from identity.domain import DirectoryId, EmployeeId, Role, UserId
from identity.domain.entities import Directory, Employee, User
from identity.infrastructure import UsersContainer
from identity.interface import get_users
from identity.interface.routers import directories_router, employees_router, users_router


class InMemoryReadRepository:
    """get_by_id / find / count over a list, filtering with the domain specs
    exactly like the SQL translator would (no spec = everything)."""

    def __init__(self, items, label):
        self.items = list(items)
        self._label = label

    async def get_by_id(self, entity_id):
        for item in self.items:
            if item.id == entity_id:
                return item
        raise NotFoundError(f"{self._label} {entity_id} not found", context=entity_id.value)

    async def find(self, spec=None, *, limit=50, offset=0):
        return self._matching(spec)[offset : offset + limit]

    async def count(self, spec=None):
        return len(self._matching(spec))

    def _matching(self, spec):
        return [item for item in self.items if spec is None or spec.is_satisfied_by(item)]


class _NullEventBus:
    def publish(self, event):
        pass


@pytest.fixture
def run():
    return asyncio.run


@pytest.fixture
def in_memory():
    return InMemoryReadRepository


@pytest.fixture
def make_employee():
    def make(n, *, role=Role.EMPLOYEE, is_active=True, phone="0102030405"):
        return Employee(
            EmployeeId(f"emp{n}"),
            user_id=UserId(f"usr{n}"),
            employee_number=f"EMP{n:07d}",
            is_active=is_active,
            phone=phone,
            role=role,
        )

    return make


@pytest.fixture
def make_user():
    def make(n, *, role=Role.EMPLOYEE, is_active=True, first_name="Ana", last_name="Dossou"):
        return User(
            UserId(f"usr{n}"),
            email=f"user{n}@pointage.bj",
            password_hash=None,
            role=role,
            first_name=first_name,
            last_name=last_name,
            is_active=is_active,
        )

    return make


@pytest.fixture
def make_directory():
    def make(n, *, name=None):
        return Directory(DirectoryId(f"dir{n}"), name=name or f"Direction {n}", code=f"D{n:03d}")

    return make


@pytest.fixture
def identity_api():
    """Real routers + real UsersContainer (so a missing handler binding fails
    the test), with only the read repositories replaced by in-memory fakes."""
    employees = InMemoryReadRepository([], "Employee")
    users = InMemoryReadRepository([], "User")
    directories = InMemoryReadRepository([], "Directory")
    container = UsersContainer(
        user_repository=None,
        directory_repository=None,
        employee_repository=None,
        site_repository=None,
        employee_assignment_repository=None,
        user_read_repository=users,
        directory_read_repository=directories,
        employee_read_repository=employees,
        site_read_repository=None,
        employee_assignment_read_repository=None,
        unit_of_work=None,
        event_bus=_NullEventBus(),
        password_hasher=None,
    )
    app = FastAPI()
    register_exception_handlers(app)
    for router in (employees_router, users_router, directories_router):
        app.include_router(router)
    app.dependency_overrides[get_users] = lambda: container
    return SimpleNamespace(client=TestClient(app), employees=employees, users=users, directories=directories)
```

- [ ] **Step 2 : écrire les tests qui échouent**

`tests/identity/unit/test_get_employee_by_id_handler.py`

```python
from identity.application.handlers import GetEmployeeByIdHandler
from identity.application.queries import GetEmployeeByIdQuery
from identity.domain import Role


def _handle(run, repo, employee_id):
    return run(GetEmployeeByIdHandler(employee_repository=repo).handle(GetEmployeeByIdQuery(employee_id=employee_id)))


def test_known_id_returns_the_employee(run, in_memory, make_employee):
    repo = in_memory([make_employee(1), make_employee(2, role=Role.MANAGER)], "Employee")
    dto = _handle(run, repo, "emp2")
    assert (dto.id, dto.employee_number, dto.role, dto.user_id) == ("emp2", "EMP0000002", Role.MANAGER, "usr2")


def test_unknown_id_returns_none(run, in_memory, make_employee):
    assert _handle(run, in_memory([make_employee(1)], "Employee"), "emp999") is None


def test_malformed_id_returns_none_instead_of_raising(run, in_memory):
    assert _handle(run, in_memory([], "Employee"), "NOT-AN-ID") is None
```

`tests/identity/api/test_employees_api.py`

```python
from identity.domain import Role


def test_get_employee_returns_the_camel_case_contract(identity_api, make_employee):
    identity_api.employees.items.append(make_employee(1, role=Role.MANAGER))
    res = identity_api.client.get("/employees/emp1")
    assert res.status_code == 200
    body = res.json()
    assert body["id"] == "emp1"
    assert body["employeeNumber"] == "EMP0000001"
    assert body["userId"] == "usr1"
    assert body["role"] == "MANAGER"
    assert body["isActive"] is True
    assert body["phone"] == "0102030405"


def test_get_employee_unknown_id_returns_404(identity_api):
    assert identity_api.client.get("/employees/emp999").status_code == 404


def test_get_employee_malformed_id_returns_404(identity_api):
    assert identity_api.client.get("/employees/NOT-AN-ID").status_code == 404


def test_list_employees_filters_by_role_and_pages(identity_api, make_employee):
    # emp1, emp3, emp5, emp7 are managers.
    identity_api.employees.items.extend(
        make_employee(n, role=Role.MANAGER if n % 2 else Role.EMPLOYEE) for n in range(1, 9)
    )
    res = identity_api.client.get("/employees", params={"role": "MANAGER", "limit": 2, "offset": 2})
    assert res.status_code == 200
    body = res.json()
    assert body["total"] == 4
    assert [e["id"] for e in body["items"]] == ["emp5", "emp7"]


def test_list_employees_filters_by_status(identity_api, make_employee):
    identity_api.employees.items.extend([make_employee(1), make_employee(2, is_active=False)])
    body = identity_api.client.get("/employees", params={"is_active": "false"}).json()
    assert [e["id"] for e in body["items"]] == ["emp2"]


def test_list_employees_rejects_an_unknown_role(identity_api):
    assert identity_api.client.get("/employees", params={"role": "BOSS"}).status_code == 422
```

- [ ] **Step 3 : vérifier l'échec**

Run : `cd /var/www/workspace/Pointage/backend && uv run pytest tests/identity -q`
Attendu : ÉCHEC — `ImportError: cannot import name 'GetEmployeeByIdHandler'`.

- [ ] **Step 4 : implémenter le handler** — `src/identity/application/handlers/get_employee_by_id_handler.py`

```python
"""Load one employee by id."""

from core.application import QueryHandler
from core.domain.errors import InvalidEntityIdError, NotFoundError

from ...domain import EmployeeId
from ...domain.repositories import IEmployeeRepository
from ..dtos import EmployeeDTO
from ..queries import GetEmployeeByIdQuery


class GetEmployeeByIdHandler(QueryHandler[GetEmployeeByIdQuery, EmployeeDTO | None]):
    """A malformed id cannot name an employee: it is a miss, not a 4xx of its own."""

    def __init__(self, *, employee_repository: IEmployeeRepository) -> None:
        super().__init__()
        self._employees = employee_repository

    async def handle(self, request: GetEmployeeByIdQuery) -> EmployeeDTO | None:
        try:
            employee = await self._employees.get_by_id(EmployeeId(request.employee_id))
        except (InvalidEntityIdError, NotFoundError):
            return None
        return EmployeeDTO.from_aggregate(employee)
```

Exporter : dans `src/identity/application/handlers/__init__.py`, ajouter `from .get_employee_by_id_handler import GetEmployeeByIdHandler` (après la ligne `get_employee_by_employee_number_handler`) et `"GetEmployeeByIdHandler",` dans `__all__` (ordre alphabétique). Dans `src/identity/application/__init__.py`, ajouter `GetEmployeeByIdHandler,` dans le bloc `from .handlers import (...)` et dans `__all__`.

- [ ] **Step 5 : enregistrer dans le container** — `src/identity/infrastructure/container.py`

Ajouter `GetEmployeeByIdHandler,` et `GetEmployeeByIdQuery,` dans l'import `from ..application import (...)`. Dans `__post_init__`, après `request_map.bind(GetEmployeesQuery, GetEmployeesHandler)` :

```python
        request_map.bind(GetEmployeeByIdQuery, GetEmployeeByIdHandler)
```

Dans `_resolve_handler`, après le bloc `GetEmployeesHandler` :

```python
        if handler_type is GetEmployeeByIdHandler:
            return GetEmployeeByIdHandler(employee_repository=self.employee_read_repository)
```

- [ ] **Step 6 : ajouter la route et convertir le rôle de la liste** — `src/identity/interface/routers/employees_router.py`

Imports : `from fastapi import APIRouter, Depends, HTTPException, status`, `from identity.application import GetEmployeeByIdQuery, GetEmployeesQuery`, `from identity.domain import Role`.

Ajouter la route **après** `list_employees` :

```python
@router.get("/{employee_id}", response_model=EmployeeResponse)
async def get_employee(
    employee_id: str,
    users: UsersContainer = Depends(get_users),  # noqa: B008
) -> EmployeeResponse:
    dto = await users.send(GetEmployeeByIdQuery(employee_id=employee_id))
    if dto is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Employee not found")
    return _employee_reponse(dto)
```

Dans `list_employees`, remplacer `role=role,` par :

```python
            # Wire enum → domain enum: the domain specs compare by identity.
            role=Role(role) if role is not None else None,
```

- [ ] **Step 7 : vérifier**

Run : `uv run pytest tests/identity -q` → tout PASSE.
Run : `uv run pytest -q` → seul `test_punch_on_a_deactivated_site_is_refused` échoue (préexistant).

- [ ] **Step 8 : commit (dépôt backend)**

```bash
cd /var/www/workspace/Pointage/backend
git add tests/identity src/identity/application/handlers/get_employee_by_id_handler.py src/identity/application/handlers/__init__.py src/identity/application/__init__.py src/identity/infrastructure/container.py src/identity/interface/routers/employees_router.py
git commit -m "feat(identity): add GET /employees/{id}

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : `GET /users` (et correction de `GetUsersHandler`)

> ⚠️ Correction de code existant, validée par l'utilisateur avant exécution : aujourd'hui `GetUsersHandler` fait `None & spec` (TypeError) et `UserRepository.find/count` appellent `translate(None)` (TypeError). On aligne sur `GetEmployeesHandler` / `EmployeeRepository`, et on ajoute un tri stable pour que la pagination soit déterministe.

**Files :**
- Create: `backend/tests/identity/unit/test_get_users_handler.py`, `backend/tests/identity/unit/test_user_read_repository.py`, `backend/tests/identity/api/test_users_api.py`
- Modify: `backend/src/identity/application/handlers/get_users_handler.py`
- Modify: `backend/src/identity/domain/repositories/user_repository.py`
- Modify: `backend/src/identity/infrastructure/persistence/user_repository.py`
- Modify: `backend/src/identity/interface/routers/users_router.py`

**Interfaces :**
- Consumes : fixtures de Task 1.
- Produces : `GET /users?role&is_active&limit(1..200, défaut 50)&offset(≥0)` → `UserListResponse` `{items: [{id, email, role, isActive, firstName, lastName, ...}], total}`.

- [ ] **Step 1 : écrire les tests qui échouent**

`tests/identity/unit/test_get_users_handler.py`

```python
from identity.application.handlers import GetUsersHandler
from identity.application.queries import GetUsersQuery
from identity.domain import Role


def _page(run, repo, **query):
    return run(GetUsersHandler(user_repository=repo).handle(GetUsersQuery(**query)))


def _users(in_memory, make_user):
    return in_memory(
        [
            make_user(1, role=Role.ADMIN),
            make_user(2),
            make_user(3, is_active=False),
            make_user(4, role=Role.ADMIN, is_active=False),
        ],
        "User",
    )


def test_without_filters_returns_everyone(run, in_memory, make_user):
    page = _page(run, _users(in_memory, make_user))
    assert (page.total, [u.id for u in page.items]) == (4, ["usr1", "usr2", "usr3", "usr4"])


def test_role_filter(run, in_memory, make_user):
    page = _page(run, _users(in_memory, make_user), role=Role.ADMIN)
    assert [u.id for u in page.items] == ["usr1", "usr4"]


def test_status_filter(run, in_memory, make_user):
    page = _page(run, _users(in_memory, make_user), is_active=False)
    assert [u.id for u in page.items] == ["usr3", "usr4"]


def test_role_and_status_filters_combine(run, in_memory, make_user):
    page = _page(run, _users(in_memory, make_user), role=Role.ADMIN, is_active=True)
    assert [u.id for u in page.items] == ["usr1"]


def test_total_counts_every_match_not_just_the_page(run, in_memory, make_user):
    page = _page(run, _users(in_memory, make_user), limit=1, offset=1)
    assert (page.total, [u.id for u in page.items]) == (4, ["usr2"])
```

`tests/identity/unit/test_user_read_repository.py` — vérifie le SQL émis, à la frontière de la base, sans base réelle.

```python
from types import SimpleNamespace

from identity.domain import Role
from identity.domain.specifications import UserRoleIs
from identity.infrastructure.persistence.user_repository import UserRepository


class CapturingSession:
    """Records the statements a repository sends; returns empty results."""

    def __init__(self):
        self.statements = []

    async def scalars(self, stmt):
        self.statements.append(stmt)
        return SimpleNamespace(all=lambda: [])

    async def scalar(self, stmt):
        self.statements.append(stmt)
        return 0


def _sql(session):
    return str(session.statements[-1]).upper()


def test_find_without_spec_has_no_where_and_a_stable_order(run):
    session = CapturingSession()
    assert run(UserRepository(session).find(None, limit=10, offset=20)) == []
    sql = _sql(session)
    assert "WHERE" not in sql
    assert "ORDER BY" in sql


def test_find_with_spec_filters_at_the_database(run):
    session = CapturingSession()
    run(UserRepository(session).find(UserRoleIs(Role.ADMIN)))
    assert "WHERE" in _sql(session)


def test_count_without_spec_counts_every_row(run):
    session = CapturingSession()
    assert run(UserRepository(session).count(None)) == 0
    assert "WHERE" not in _sql(session)
```

`tests/identity/api/test_users_api.py`

```python
from identity.domain import Role


def test_list_users_returns_the_page_contract(identity_api, make_user):
    identity_api.users.items.extend([make_user(1, first_name="Ana", last_name="Dossou"), make_user(2)])
    res = identity_api.client.get("/users", params={"limit": 1})
    assert res.status_code == 200
    body = res.json()
    assert body["total"] == 2
    [user] = body["items"]
    # createdAt / updatedAt are filled by the entity itself: only their presence is checked.
    assert {k: user[k] for k in ("id", "email", "role", "isActive", "firstName", "lastName")} == {
        "id": "usr1",
        "email": "user1@pointage.bj",
        "role": "EMPLOYEE",
        "isActive": True,
        "firstName": "Ana",
        "lastName": "Dossou",
    }
    assert "createdAt" in user and "updatedAt" in user


def test_list_users_filters_by_role(identity_api, make_user):
    identity_api.users.items.extend([make_user(1, role=Role.HR), make_user(2)])
    body = identity_api.client.get("/users", params={"role": "HR"}).json()
    assert [u["id"] for u in body["items"]] == ["usr1"]


def test_list_users_rejects_invalid_paging(identity_api):
    assert identity_api.client.get("/users", params={"limit": 0}).status_code == 422
    assert identity_api.client.get("/users", params={"offset": -1}).status_code == 422
    assert identity_api.client.get("/users", params={"role": "BOSS"}).status_code == 422
```

- [ ] **Step 2 : vérifier l'échec**

Run : `uv run pytest tests/identity -q`
Attendu : ÉCHEC — `TypeError` dans `GetUsersHandler` (filtres), `TypeError` dans le translator (`find(None)`), 404/405 sur `GET /users`.

- [ ] **Step 3 : corriger le handler** — `src/identity/application/handlers/get_users_handler.py`, remplacer le corps de `handle` :

```python
    async def handle(self, request: GetUsersQuery) -> UsersPageDTO:
        spec: Specification[User] | None = None
        for leaf in (
            UserRoleIs(request.role) if request.role is not None else None,
            UserIsActiveIs(request.is_active) if request.is_active is not None else None,
        ):
            if leaf is not None:
                spec = leaf if spec is None else spec & leaf

        users = await self._users.find(spec, limit=request.limit, offset=request.offset)
        total = await self._users.count(spec)
        return UsersPageDTO(
            items=tuple(UserDTO.from_aggregate(u) for u in users),
            total=total,
        )
```

- [ ] **Step 4 : accepter l'absence de filtre dans le repository**

`src/identity/domain/repositories/user_repository.py` : dans `find` et `count`, typer `spec: Specification[User] | None` et compléter les docstrings par « ``None`` matches every user. »

`src/identity/infrastructure/persistence/user_repository.py`, remplacer `find` et `count` :

```python
    async def find(
        self, spec: Specification[User] | None, *, limit: int = 50, offset: int = 0
    ) -> list[User]:
        stmt = select(UserModel)
        if spec is not None:
            stmt = stmt.where(self._translator.translate(spec))
        stmt = stmt.order_by(UserModel.created_at, UserModel.id).limit(limit).offset(offset)
        rows = (await self._session.scalars(stmt)).all()
        return [self._to_aggregate(row) for row in rows]

    async def count(self, spec: Specification[User] | None) -> int:
        stmt = select(func.count()).select_from(UserModel)
        if spec is not None:
            stmt = stmt.where(self._translator.translate(spec))
        return await self._session.scalar(stmt) or 0
```

- [ ] **Step 5 : ajouter la route** — `src/identity/interface/routers/users_router.py`

Imports : `from fastapi import APIRouter, Depends, Query, status` ; ajouter `GetUsersQuery,` dans l'import `from ...application import (...)` ; `from ...domain import Role` ; ajouter `RoleSchema, UserListResponse,` dans l'import `from ..schemas import (...)`. Mettre à jour la docstring du module : « account creation and listing ».

```python
@router.get("", response_model=UserListResponse)
async def list_users(
    role: RoleSchema | None = None,
    is_active: bool | None = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    users: UsersContainer = Depends(get_users),  # noqa: B008
) -> UserListResponse:
    """Members, oldest first. Open to every profile for now (no role guard yet)."""
    page = await users.send(
        GetUsersQuery(
            role=Role(role) if role is not None else None,
            is_active=is_active,
            limit=limit,
            offset=offset,
        )
    )
    return UserListResponse.model_validate(page, from_attributes=True)
```

- [ ] **Step 6 : vérifier**

Run : `uv run pytest tests/identity -q` → PASSE. `uv run pytest -q` → seul l'échec préexistant.

- [ ] **Step 7 : commit (dépôt backend)**

```bash
git add tests/identity src/identity/application/handlers/get_users_handler.py src/identity/domain/repositories/user_repository.py src/identity/infrastructure/persistence/user_repository.py src/identity/interface/routers/users_router.py
git commit -m "feat(identity): add GET /users and fix unfiltered user queries

GetUsersHandler combined filters onto None and UserRepository translated a
None spec: both raised TypeError. Listing is now ordered for stable paging.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : `GET /directories`

**Files :**
- Create: `backend/src/identity/application/queries/get_directories.py`
- Create: `backend/src/identity/application/handlers/get_directories_handler.py`
- Create: `backend/tests/identity/unit/test_get_directories_handler.py`, `backend/tests/identity/unit/test_directory_read_repository.py`, `backend/tests/identity/api/test_directories_api.py`
- Modify: `backend/src/identity/application/dtos/user_dtos.py`, `backend/src/identity/application/dtos/__init__.py`
- Modify: `backend/src/identity/application/queries/__init__.py`, `backend/src/identity/application/handlers/__init__.py`, `backend/src/identity/application/__init__.py`
- Modify: `backend/src/identity/domain/repositories/directory_repository.py`
- Modify: `backend/src/identity/infrastructure/persistence/directory_repository.py`, `backend/src/identity/infrastructure/persistence/event_sourced_directory_repository.py`
- Modify: `backend/src/identity/infrastructure/container.py`
- Modify: `backend/src/identity/interface/schemas.py`, `backend/src/identity/interface/routers/directories_router.py`

**Interfaces :**
- Produces : `GET /directories?limit(1..200, défaut 50)&offset(≥0)` → `{items: [{id, name, code, parentDirectoryId, createdAt, updatedAt}], total}`, trié par nom.

- [ ] **Step 1 : écrire les tests qui échouent**

`tests/identity/unit/test_get_directories_handler.py`

```python
from identity.application.handlers import GetDirectoriesHandler
from identity.application.queries import GetDirectoriesQuery


def _page(run, repo, **query):
    return run(GetDirectoriesHandler(directory_repository=repo).handle(GetDirectoriesQuery(**query)))


def test_no_directory_gives_an_empty_page(run, in_memory):
    page = _page(run, in_memory([], "Directory"))
    assert (page.items, page.total) == ((), 0)


def test_pages_with_the_total_of_every_directory(run, in_memory, make_directory):
    repo = in_memory([make_directory(n) for n in range(1, 6)], "Directory")
    page = _page(run, repo, limit=2, offset=2)
    assert page.total == 5
    assert [(d.id, d.name, d.code) for d in page.items] == [("dir3", "Direction 3", "D003"), ("dir4", "Direction 4", "D004")]
```

`tests/identity/unit/test_directory_read_repository.py`

```python
from types import SimpleNamespace

from identity.infrastructure.persistence.directory_repository import DirectoryRepository


class CapturingSession:
    def __init__(self):
        self.statements = []

    async def scalars(self, stmt):
        self.statements.append(stmt)
        return SimpleNamespace(all=lambda: [])

    async def scalar(self, stmt):
        self.statements.append(stmt)
        return 0


def test_find_orders_by_name_and_pages(run):
    session = CapturingSession()
    assert run(DirectoryRepository(session).find(limit=10, offset=20)) == []
    sql = str(session.statements[-1]).upper()
    assert "ORDER BY" in sql and "LIMIT" in sql and "OFFSET" in sql


def test_count_counts_every_directory(run):
    session = CapturingSession()
    assert run(DirectoryRepository(session).count()) == 0
    assert "COUNT" in str(session.statements[-1]).upper()
```

`tests/identity/api/test_directories_api.py`

```python
def test_list_directories_returns_the_page_contract(identity_api, make_directory):
    identity_api.directories.items.extend([make_directory(1, name="Direction générale"), make_directory(2)])
    res = identity_api.client.get("/directories", params={"limit": 1})
    assert res.status_code == 200
    body = res.json()
    assert body["total"] == 2
    assert body["items"][0]["id"] == "dir1"
    assert body["items"][0]["name"] == "Direction générale"
    assert body["items"][0]["code"] == "D001"
    assert "parentDirectoryId" in body["items"][0]


def test_list_directories_rejects_invalid_paging(identity_api):
    assert identity_api.client.get("/directories", params={"limit": 500}).status_code == 422
    assert identity_api.client.get("/directories", params={"offset": -1}).status_code == 422
```

- [ ] **Step 2 : vérifier l'échec**

Run : `uv run pytest tests/identity -q` → ÉCHEC (`ImportError: GetDirectoriesHandler`).

- [ ] **Step 3 : DTO, query, handler**

`src/identity/application/dtos/user_dtos.py`, après `DirectoryDTO` :

```python
@dataclass(frozen=True)
class DirectoriesPageDTO(DTO):
    items: tuple[DirectoryDTO, ...]
    total: int
```

L'exporter dans `dtos/__init__.py` (import + `__all__`).

`src/identity/application/queries/get_directories.py`

```python
"""Page through the directories."""

from dataclasses import dataclass

from core.application import Query

from ..dtos import DirectoriesPageDTO


@dataclass(frozen=True)
class GetDirectoriesQuery(Query):
    limit: int = 50
    offset: int = 0

    Result = DirectoriesPageDTO
```

L'exporter dans `queries/__init__.py` et `application/__init__.py` (import + `__all__`).

`src/identity/application/handlers/get_directories_handler.py`

```python
"""Paged directory listing, by name."""

from core.application import QueryHandler

from ...domain.repositories import IDirectoryRepository
from ..dtos import DirectoriesPageDTO, DirectoryDTO
from ..queries import GetDirectoriesQuery


class GetDirectoriesHandler(QueryHandler[GetDirectoriesQuery, DirectoriesPageDTO]):
    def __init__(self, *, directory_repository: IDirectoryRepository) -> None:
        super().__init__()
        self._directories = directory_repository

    async def handle(self, request: GetDirectoriesQuery) -> DirectoriesPageDTO:
        directories = await self._directories.find(limit=request.limit, offset=request.offset)
        total = await self._directories.count()
        return DirectoriesPageDTO(
            items=tuple(DirectoryDTO.from_aggregate(d) for d in directories),
            total=total,
        )
```

L'exporter dans `handlers/__init__.py` et `application/__init__.py`.

- [ ] **Step 4 : repository**

`src/identity/domain/repositories/directory_repository.py`, ajouter dans `IDirectoryRepository` :

```python
    @abstractmethod
    async def find(self, *, limit: int = 50, offset: int = 0) -> list[Directory]:
        """Directories by name, paged."""
        ...

    @abstractmethod
    async def count(self) -> int:
        """Every directory — the ``total`` of a paged listing."""
        ...
```

`src/identity/infrastructure/persistence/directory_repository.py` : `from sqlalchemy import delete, func, insert, or_, select, update`, puis après `exists_by_code_or_name` :

```python
    async def find(self, *, limit: int = 50, offset: int = 0) -> list[Directory]:
        stmt = (
            select(DirectoryModel)
            .order_by(DirectoryModel.name, DirectoryModel.id)
            .limit(limit)
            .offset(offset)
        )
        rows = (await self._session.scalars(stmt)).all()
        return [self._to_aggregate(row) for row in rows]

    async def count(self) -> int:
        return await self._session.scalar(select(func.count()).select_from(DirectoryModel)) or 0
```

`src/identity/infrastructure/persistence/event_sourced_directory_repository.py`, même convention que `EventSourcedUserRepository` :

```python
    async def find(self, *, limit: int = 50, offset: int = 0) -> list[Directory]:
        raise NotImplementedError("Listing directories is a query: read the directories read model")

    async def count(self) -> int:
        raise NotImplementedError("Counting directories is a query: read the directories read model")
```

- [ ] **Step 5 : container** — importer `GetDirectoriesHandler, GetDirectoriesQuery` depuis `..application`, puis :

```python
        request_map.bind(GetDirectoriesQuery, GetDirectoriesHandler)
```

```python
        if handler_type is GetDirectoriesHandler:
            return GetDirectoriesHandler(directory_repository=self.directory_read_repository)
```

- [ ] **Step 6 : schéma et route**

`src/identity/interface/schemas.py`, juste après `DirectoryResponse` :

```python
class DirectoryListResponse(_CamelSchema):
    items: list[DirectoryResponse]
    total: int
```

`src/identity/interface/routers/directories_router.py` : `from fastapi import APIRouter, Depends, Query, status`, `from identity.application.queries import GetDirectoriesQuery, GetDirectorySitesQuery`, ajouter `DirectoryListResponse` à l'import des schémas, puis :

```python
@router.get("", response_model=DirectoryListResponse)
async def list_directories(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    users: UsersContainer = Depends(get_users),  # noqa: B008
) -> DirectoryListResponse:
    """Directories by name, paged."""
    page = await users.send(GetDirectoriesQuery(limit=limit, offset=offset))
    return DirectoryListResponse.model_validate(page, from_attributes=True)
```

- [ ] **Step 7 : vérifier** — `uv run pytest tests/identity -q` → PASSE ; `uv run pytest -q` → seul l'échec préexistant.

- [ ] **Step 8 : commit (dépôt backend)**

```bash
git add tests/identity src/identity/application src/identity/domain/repositories/directory_repository.py src/identity/infrastructure/persistence/directory_repository.py src/identity/infrastructure/persistence/event_sourced_directory_repository.py src/identity/infrastructure/container.py src/identity/interface/schemas.py src/identity/interface/routers/directories_router.py
git status --short   # importer.py doit rester non stagé
git commit -m "feat(identity): add GET /directories

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Partie B — Frontend : fondations

### Task 4 : `ApiClient`, `Paged`, `Role`, `formatDate`

**Files :**
- Modify: `lib/core/api_client.dart`
- Create: `lib/core/paged.dart`, `lib/core/role.dart`, `lib/core/format.dart`
- Test: `test/core/unit/api_client_test.dart`, `test/core/unit/paged_test.dart`, `test/core/unit/role_test.dart`

**Interfaces :**
- Produces : `ApiClient.get(String path, {String? accessToken, Map<String, String>? query}) → Future<dynamic>` ; `ApiClient.post(...)` inchangé ; `Paged<T>({required List<T> items, required int total})` + `Paged.fromJson(Map<String, dynamic>, T Function(Map<String, dynamic>))` ; `enum Role { employee, manager, hr, payroll, admin }` avec `wire`, `label`, `Role.fromWire(String)` ; `String formatDate(DateTime?)` (`'—'` si null, sinon `jj/mm/aaaa`).

- [ ] **Step 1 : écrire les tests qui échouent**

`test/core/unit/api_client_test.dart`

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';

ApiClient clientReplying(int status, Object? body, {void Function(http.Request)? onRequest}) =>
    ApiClient(MockClient((req) async {
      onRequest?.call(req);
      return http.Response.bytes(body == null ? [] : utf8.encode(body is String ? body : jsonEncode(body)), status);
    }));

void main() {
  test('get sends the bearer token and the query parameters', () async {
    late http.Request sent;
    final api = clientReplying(200, {'items': [], 'total': 0}, onRequest: (r) => sent = r);
    final data = await api.get('/employees', accessToken: 'tok', query: {'limit': '20', 'offset': '0'});
    expect(sent.headers['Authorization'], 'Bearer tok');
    expect(sent.url.path, '/employees');
    expect(sent.url.queryParameters, {'limit': '20', 'offset': '0'});
    expect(data, {'items': [], 'total': 0});
  });

  test('get without query parameters adds no "?"', () async {
    late http.Request sent;
    await clientReplying(200, [], onRequest: (r) => sent = r).get('/directories/dir1/sites');
    expect(sent.url.hasQuery, isFalse);
  });

  test('a known backend code is translated', () async {
    final api = clientReplying(403, {'code': 'TOO_FAR_FROM_WORKPLACE', 'message': 'Too far'});
    await expectLater(
      api.post('/time-entries', {}),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 403)
          .having((e) => e.code, 'code', 'TOO_FAR_FROM_WORKPLACE')
          .having((e) => e.message, 'message', contains('trop loin'))),
    );
  });

  test('422 is reported as invalid input on get and post', () async {
    final api = clientReplying(422, {'detail': []});
    await expectLater(api.get('/users'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Vérifiez les informations saisies.')));
    await expectLater(api.post('/employees', {}), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Vérifiez les informations saisies.')));
  });

  test('an unknown backend message is replaced by a French one', () async {
    final api = clientReplying(409, {'code': 'SOMETHING_NEW', 'message': 'Stale version'});
    await expectLater(api.get('/x'), throwsA(isA<ApiException>().having((e) => e.message, 'message', startsWith('Conflit'))));
  });

  test('a non-JSON error body still gives a readable error', () async {
    final api = clientReplying(502, '<html>Bad gateway</html>');
    await expectLater(api.get('/x'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Erreur serveur (502)')));
  });

  test('an empty success body decodes to an empty map', () async {
    expect(await clientReplying(202, null).post('/auth/otp/request', {'identifier': 'x'}), isEmpty);
  });
}
```

`test/core/unit/paged_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/paged.dart';

void main() {
  test('fromJson maps every item and keeps the total', () {
    final page = Paged.fromJson({'items': [{'v': 1}, {'v': 2}], 'total': 7}, (j) => j['v'] as int);
    expect(page.items, [1, 2]);
    expect(page.total, 7);
  });
}
```

`test/core/unit/role_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/role.dart';

void main() {
  test('every backend role has a French label', () {
    expect(Role.values.map((r) => r.wire), ['EMPLOYEE', 'MANAGER', 'HR', 'PAYROLL', 'ADMIN']);
    expect(Role.fromWire('HR').label, 'RH');
  });

  test('an unknown role is a format error, not a silent default', () {
    expect(() => Role.fromWire('BOSS'), throwsFormatException);
  });
}
```

- [ ] **Step 2 : vérifier l'échec** — `flutter test test/core/unit` → ÉCHEC (fichiers manquants, paramètre `query` inexistant).

- [ ] **Step 3 : implémenter**

`lib/core/paged.dart`

```dart
/// Une page de résultats du backend : `{items, total}`.
/// (`Page` est déjà une classe de Flutter, d'où le nom.)
class Paged<T> {
  const Paged({required this.items, required this.total});

  final List<T> items;

  /// Nombre total d'éléments correspondant à la requête, toutes pages confondues.
  final int total;

  factory Paged.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) item) => Paged(
        items: (j['items'] as List).map((e) => item(e as Map<String, dynamic>)).toList(),
        total: j['total'] as int,
      );
}
```

`lib/core/role.dart`

```dart
/// Rôles du backend (`RoleSchema`), du moins au plus élevé.
enum Role {
  employee('EMPLOYEE', 'Employé'),
  manager('MANAGER', 'Manager'),
  hr('HR', 'RH'),
  payroll('PAYROLL', 'Paie'),
  admin('ADMIN', 'Admin');

  const Role(this.wire, this.label);

  /// Valeur échangée avec l'API.
  final String wire;
  final String label;

  static Role fromWire(String value) =>
      values.firstWhere((r) => r.wire == value, orElse: () => throw FormatException('Rôle inconnu : $value'));
}
```

`lib/core/format.dart`

```dart
String _two(int n) => n.toString().padLeft(2, '0');

/// `jj/mm/aaaa`, ou un tiret quand la date est absente.
String formatDate(DateTime? d) => d == null ? '—' : '${_two(d.day)}/${_two(d.month)}/${d.year}';
```

`lib/core/api_client.dart` — garder `apiUrl` et `ApiException` tels quels ; compléter `_messages` et remplacer la classe `ApiClient` :

```dart
/// Codes d'erreur du backend (`DomainErrorSchema.code`) traduits pour l'utilisateur.
const _messages = {
  'INVALID_LOGIN_CODE': 'Code incorrect ou expiré.',
  'INVALID_CREDENTIALS': 'Identifiant ou mot de passe incorrect.',
  'INVALID_REFRESH_TOKEN': 'Session expirée, reconnectez-vous.',
  'INVALID_ACCESS_TOKEN': 'Session expirée, reconnectez-vous.',
  'ACCESS_DENIED': "Vous n'avez pas accès à cette action.",
  'ROLE_PERMISSION_DENIED': "Vous n'avez pas accès à cette action.",
  'TOO_FAR_FROM_WORKPLACE': 'Vous êtes trop loin de votre lieu de travail pour pointer (100 m maximum).',
  'EMPLOYEE_NOT_ASSIGNED': "Vous n'avez pas d'affectation active aujourd'hui. Contactez votre responsable.",
  'EMPLOYEE_WITH_THIS_NUMBER_ALREADY_EXISTS': 'Ce matricule est déjà utilisé.',
  'SITE_NOT_IN_DIRECTORY': "Ce site n'appartient pas à l'annuaire choisi.",
  'DIRECTORY_HAS_NO_SITE': "Cet annuaire n'a aucun site : créez-en un d'abord.",
  'SITE_INACTIVE': 'Ce site est désactivé.',
  'PUNCH_ALREADY_EXISTS': 'Ce pointage a déjà été enregistré.',
  'INVALID_ENTITY_ID': 'Identifiant invalide.',
  'NOT_FOUND': 'Élément introuvable.',
  'CONFLICT': 'Conflit : cet élément existe déjà ou a été modifié entre-temps.',
};

/// Message par statut HTTP quand le code d'erreur n'est pas connu :
/// les messages bruts du backend (en anglais) ne sont jamais montrés.
String _fallback(int status) => switch (status) {
      401 => 'Session expirée, reconnectez-vous.',
      403 => "Vous n'avez pas accès à cette action.",
      404 => 'Élément introuvable.',
      409 => 'Conflit : cet élément existe déjà ou a été modifié entre-temps.',
      422 => 'Vérifiez les informations saisies.',
      >= 500 => 'Erreur serveur ($status)',
      _ => 'Requête refusée ($status)',
    };

class ApiClient {
  ApiClient(this._http);
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? accessToken}) async {
    final res = await _http
        .post(_uri(path), headers: _headers(accessToken), body: jsonEncode(body))
        .timeout(_timeout);
    return _handle(res) as Map<String, dynamic>;
  }

  Future<dynamic> get(String path, {String? accessToken, Map<String, String>? query}) async {
    final res = await _http.get(_uri(path, query), headers: _headers(accessToken)).timeout(_timeout);
    return _handle(res);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$apiUrl$path');
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> _headers(String? accessToken) => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  /// Corps JSON décodé, ou [ApiException] avec un message lisible.
  dynamic _handle(http.Response res) {
    Object? data;
    try {
      data = res.bodyBytes.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      data = null; // page d'erreur HTML d'un proxy, par exemple
    }
    if (res.statusCode < 400 && data != null) return data;
    final code = data is Map ? data['code'] as String? : null;
    throw ApiException(_messages[code] ?? _fallback(res.statusCode), status: res.statusCode, code: code);
  }
}
```

Note : un corps de succès non-JSON lève désormais une `ApiException` (« Requête refusée (200) »). Le backend ne renvoie jamais ce cas, c'est voulu : ça évite un crash plus loin.

- [ ] **Step 4 : vérifier** — `flutter test test/core/unit` → PASSE ; `flutter analyze` → seul le `withOpacity` de l'ancien `employee_screen.dart` (supprimé en Task 5).

- [ ] **Step 5 : commit (dépôt frontend)**

```bash
cd /var/www/workspace/Pointage/frontend
git add lib/core test/core
git commit -m "feat(core): share API error handling, add Paged, Role and formatDate

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : modèles et repositories (employee, user, directory)

**Files :**
- Rewrite: `lib/features/employee/employee_model.dart`, `lib/features/employee/employee_repository.dart`
- Delete: `lib/features/employee/employee_screen.dart`, `lib/features/employee/employee_controller.dart` (le controller est réécrit en Task 6 ; aucun autre fichier ne les importe)
- Create: `lib/features/user/user_model.dart`, `lib/features/user/user_repository.dart`
- Create: `lib/features/directory/directory_model.dart`, `lib/features/directory/directory_repository.dart`
- Modify: `lib/features/auth/session_provider.dart` (ajout de `requireAccessToken`)
- Test: `test/features/employee/unit/employee_model_test.dart`, `test/features/employee/unit/employee_repository_test.dart`, `test/features/user/unit/user_test.dart`, `test/features/directory/unit/directory_test.dart`

**Interfaces :**
- Produces :
  - `Employee({required String id, required String userId, required String employeeNumber, required Role role, required bool isActive, String? phone, DateTime? createdAt, DateTime? updatedAt})` + `Employee.fromJson`
  - `EmployeeFilters({String search = '', Role? role, bool? isActive})` + `bool get isEmpty`
  - `EmployeeDraft({required String userId, required String directoryId, required String employeeNumber, Role role = Role.employee, String? phone, bool isActive = false, String? siteId, DateTime? assignmentStartDate})` + `Map<String, dynamic> toJson()` (snake_case)
  - `EmployeeRepository.list(String accessToken, {EmployeeFilters filters = const EmployeeFilters(), int limit = 20, int offset = 0}) → Future<Paged<Employee>>`, `getById(String accessToken, String id) → Future<Employee>`, `create(String accessToken, EmployeeDraft draft) → Future<Employee>` ; `employeeRepositoryProvider`
  - `AppUser({required String id, required String email, required Role role, required bool isActive, String? firstName, String? lastName})` + `String get displayName` ; `UserRepository.list(String accessToken, {int limit = 100, int offset = 0}) → Future<Paged<AppUser>>` ; `userRepositoryProvider`
  - `Directory({required String id, required String name, required String code})`, `Site({required String id, required String name})` ; `DirectoryRepository.list(String accessToken, {int limit = 100, int offset = 0}) → Future<Paged<Directory>>`, `sites(String accessToken, String directoryId) → Future<List<Site>>` ; `directoryRepositoryProvider`
  - `Future<String> requireAccessToken(Ref ref)` (lève `ApiException(status: 401)` si la session est terminée)

- [ ] **Step 1 : écrire les tests qui échouent**

`test/features/employee/unit/employee_model_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/employee/employee_model.dart';

void main() {
  test('Employee reads the backend EmployeeResponse', () {
    final e = Employee.fromJson({
      'id': 'emp1',
      'role': 'MANAGER',
      'employeeNumber': 'EMP0000001',
      'isActive': true,
      'phone': null,
      'userId': 'usr1',
      'createdAt': '2026-10-16T08:30:00Z',
      'updatedAt': null,
    });
    expect(e.id, 'emp1');
    expect(e.role, Role.manager);
    expect(e.isActive, isTrue);
    expect(e.phone, isNull);
    expect(e.createdAt, DateTime.utc(2026, 10, 16, 8, 30).toLocal());
    expect(e.updatedAt, isNull);
  });

  test('EmployeeDraft sends snake_case and omits empty optional fields', () {
    const draft = EmployeeDraft(userId: 'usr1', directoryId: 'dir1', employeeNumber: 'EMP0000001', phone: '');
    expect(draft.toJson(), {
      'user_id': 'usr1',
      'directory_id': 'dir1',
      'employee_number': 'EMP0000001',
      'role': 'EMPLOYEE',
      'is_active': false,
    });
  });

  test('EmployeeDraft sends the optional fields when set', () {
    final draft = EmployeeDraft(
      userId: 'usr1',
      directoryId: 'dir1',
      employeeNumber: 'EMP0000001',
      role: Role.hr,
      phone: '0102030405',
      isActive: true,
      siteId: 'sit1',
      assignmentStartDate: DateTime(2026, 3, 5),
    );
    expect(draft.toJson(), containsPair('assignment_start_date', '2026-03-05'));
    expect(draft.toJson(), containsPair('site_id', 'sit1'));
    expect(draft.toJson(), containsPair('phone', '0102030405'));
    expect(draft.toJson(), containsPair('role', 'HR'));
  });

  test('EmployeeFilters is empty only without any criterion', () {
    expect(const EmployeeFilters().isEmpty, isTrue);
    expect(const EmployeeFilters(isActive: false).isEmpty, isFalse);
  });
}
```

`test/features/employee/unit/employee_repository_test.dart`

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';

const _employeeJson = {
  'id': 'emp1', 'role': 'EMPLOYEE', 'employeeNumber': 'EMP0000001', 'isActive': true, 'phone': null, 'userId': 'usr1',
};

void main() {
  late List<http.Request> sent;
  EmployeeRepository repo(int status, Object body) {
    sent = [];
    return EmployeeRepository(ApiClient(MockClient((req) async {
      sent.add(req);
      return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
    })));
  }

  test('list sends filters and paging as backend query parameters', () async {
    final page = await repo(200, {'items': [_employeeJson], 'total': 41}).list(
      'tok',
      filters: const EmployeeFilters(search: 'EMP0000001', role: Role.manager, isActive: false),
      offset: 20,
    );
    expect(sent.single.url.queryParameters, {
      'employee_number': 'EMP0000001', 'role': 'MANAGER', 'is_active': 'false', 'limit': '20', 'offset': '20',
    });
    expect(page.total, 41);
    expect(page.items.single.employeeNumber, 'EMP0000001');
  });

  test('list without filters only sends paging', () async {
    await repo(200, {'items': [], 'total': 0}).list('tok');
    expect(sent.single.url.queryParameters, {'limit': '20', 'offset': '0'});
  });

  test('getById reads one employee', () async {
    final e = await repo(200, _employeeJson).getById('tok', 'emp1');
    expect(sent.single.url.path, '/employees/emp1');
    expect(e.id, 'emp1');
  });

  test('getById surfaces a 404 as ApiException', () async {
    await expectLater(repo(404, {'detail': 'Employee not found'}).getById('tok', 'emp9'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
  });

  test('create posts the draft and returns the created employee', () async {
    final e = await repo(201, _employeeJson)
        .create('tok', const EmployeeDraft(userId: 'usr1', directoryId: 'dir1', employeeNumber: 'EMP0000001'));
    expect(sent.single.method, 'POST');
    expect(jsonDecode(sent.single.body), containsPair('user_id', 'usr1'));
    expect(e.id, 'emp1');
  });
}
```

`test/features/user/unit/user_test.dart`

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/user/user_model.dart';
import 'package:pointage/features/user/user_repository.dart';

Map<String, dynamic> userJson({String? first, String? last}) => {
      'id': 'usr1', 'email': 'ana@pointage.bj', 'role': 'EMPLOYEE', 'isActive': true,
      'firstName': first, 'lastName': last, 'avatarUrl': null, 'lastActiveAt': null, 'createdAt': null, 'updatedAt': null,
    };

void main() {
  test('displayName shows the name and the email', () {
    expect(AppUser.fromJson(userJson(first: 'Ana', last: 'Dossou')).displayName, 'Ana Dossou — ana@pointage.bj');
  });

  test('displayName falls back to the email when there is no name', () {
    expect(AppUser.fromJson(userJson(first: ' ', last: null)).displayName, 'ana@pointage.bj');
  });

  test('list reads a page of users', () async {
    late http.Request sent;
    final repo = UserRepository(ApiClient(MockClient((req) async {
      sent = req;
      return http.Response(jsonEncode({'items': [userJson()], 'total': 1}), 200);
    })));
    final page = await repo.list('tok');
    expect(sent.url.queryParameters, {'limit': '100', 'offset': '0'});
    expect(page.items.single.email, 'ana@pointage.bj');
  });
}
```

`test/features/directory/unit/directory_test.dart`

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/directory/directory_repository.dart';

void main() {
  final responses = <String, Object>{
    '/directories': {
      'items': [{'id': 'dir1', 'name': 'Direction générale', 'code': 'DG', 'parentDirectoryId': null}],
      'total': 1,
    },
    '/directories/dir1/sites': [
      {
        'id': 'sit1', 'directoryId': 'dir1', 'name': 'Siège Cotonou', 'kind': 'PRINCIPAL', 'active': true,
        'location': {'latitude': 6.36, 'longitude': 2.41}, 'address': null,
      },
    ],
  };
  final repo = DirectoryRepository(ApiClient(MockClient(
    (req) async => http.Response.bytes(utf8.encode(jsonEncode(responses[req.url.path])), 200),
  )));

  test('list reads a page of directories', () async {
    final page = await repo.list('tok');
    expect(page.items.single.name, 'Direction générale');
    expect(page.items.single.code, 'DG');
  });

  test('sites reads the sites of one directory', () async {
    final sites = await repo.sites('tok', 'dir1');
    expect(sites.single.id, 'sit1');
    expect(sites.single.name, 'Siège Cotonou');
  });
}
```

- [ ] **Step 2 : vérifier l'échec** — `flutter test test/features` → ÉCHEC (classes manquantes).

- [ ] **Step 3 : implémenter**

`lib/features/employee/employee_model.dart`

```dart
import '../../core/role.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Fiche employé (`EmployeeResponse`). Le lien vers l'annuaire passe par les
/// affectations côté backend : il n'est pas sur l'employé.
class Employee {
  const Employee({
    required this.id,
    required this.userId,
    required this.employeeNumber,
    required this.role,
    required this.isActive,
    this.phone,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String employeeNumber;
  final Role role;
  final bool isActive;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        userId: j['userId'] as String,
        employeeNumber: j['employeeNumber'] as String,
        role: Role.fromWire(j['role'] as String),
        isActive: j['isActive'] as bool,
        phone: j['phone'] as String?,
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
      );
}

/// Critères de la liste. [search] est un matricule exact (le backend ne fait pas de recherche partielle).
class EmployeeFilters {
  const EmployeeFilters({this.search = '', this.role, this.isActive});

  final String search;
  final Role? role;
  final bool? isActive;

  bool get isEmpty => search.isEmpty && role == null && isActive == null;
}

/// Données du formulaire de création (`POST /employees`).
class EmployeeDraft {
  const EmployeeDraft({
    required this.userId,
    required this.directoryId,
    required this.employeeNumber,
    this.role = Role.employee,
    this.phone,
    this.isActive = false,
    this.siteId,
    this.assignmentStartDate,
  });

  final String userId;
  final String directoryId;
  final String employeeNumber;
  final Role role;
  final String? phone;
  final bool isActive;

  /// null = site principal de l'annuaire.
  final String? siteId;

  /// null = aujourd'hui (décidé par le backend).
  final DateTime? assignmentStartDate;

  /// En snake_case : `CreateEmployeeRequest` n'accepte pas le camelCase.
  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'directory_id': directoryId,
        'employee_number': employeeNumber,
        'role': role.wire,
        'is_active': isActive,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (siteId != null) 'site_id': siteId,
        if (assignmentStartDate != null) 'assignment_start_date': _isoDate(assignmentStartDate!),
      };
}
```

`lib/features/employee/employee_repository.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/paged.dart';
import 'employee_model.dart';

/// Routes `/employees` du backend.
class EmployeeRepository {
  EmployeeRepository(this._api);
  final ApiClient _api;

  Future<Paged<Employee>> list(
    String accessToken, {
    EmployeeFilters filters = const EmployeeFilters(),
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _api.get('/employees', accessToken: accessToken, query: {
      if (filters.search.isNotEmpty) 'employee_number': filters.search,
      if (filters.role != null) 'role': filters.role!.wire,
      if (filters.isActive != null) 'is_active': '${filters.isActive}',
      'limit': '$limit',
      'offset': '$offset',
    });
    return Paged.fromJson(data as Map<String, dynamic>, Employee.fromJson);
  }

  Future<Employee> getById(String accessToken, String id) async =>
      Employee.fromJson(await _api.get('/employees/$id', accessToken: accessToken) as Map<String, dynamic>);

  Future<Employee> create(String accessToken, EmployeeDraft draft) async =>
      Employee.fromJson(await _api.post('/employees', draft.toJson(), accessToken: accessToken));
}

final employeeRepositoryProvider = Provider((ref) => EmployeeRepository(ref.watch(apiClientProvider)));
```

`lib/features/user/user_model.dart`

```dart
import '../../core/role.dart';

/// Compte utilisateur (`UserResponse`), proposé à la création d'un employé.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.isActive,
    this.firstName,
    this.lastName,
  });

  final String id;
  final String email;
  final Role role;
  final bool isActive;
  final String? firstName;
  final String? lastName;

  /// « Prénom Nom — email », ou l'email seul quand le nom est vide.
  String get displayName {
    final name = [firstName, lastName].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');
    return name.isEmpty ? email : '$name — $email';
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        role: Role.fromWire(j['role'] as String),
        isActive: j['isActive'] as bool,
        firstName: j['firstName'] as String?,
        lastName: j['lastName'] as String?,
      );
}
```

`lib/features/user/user_repository.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/paged.dart';
import 'user_model.dart';

/// Routes `/users` du backend.
class UserRepository {
  UserRepository(this._api);
  final ApiClient _api;

  Future<Paged<AppUser>> list(String accessToken, {int limit = 100, int offset = 0}) async {
    final data = await _api.get('/users', accessToken: accessToken, query: {'limit': '$limit', 'offset': '$offset'});
    return Paged.fromJson(data as Map<String, dynamic>, AppUser.fromJson);
  }
}

final userRepositoryProvider = Provider((ref) => UserRepository(ref.watch(apiClientProvider)));
```

`lib/features/directory/directory_model.dart`

```dart
/// Annuaire (`DirectoryResponse`) : une entité à laquelle les employés sont affectés.
class Directory {
  const Directory({required this.id, required this.name, required this.code});

  final String id;
  final String name;
  final String code;

  factory Directory.fromJson(Map<String, dynamic> j) =>
      Directory(id: j['id'] as String, name: j['name'] as String, code: j['code'] as String);
}

/// Site d'un annuaire (`SiteResponse`), réduit à ce dont le formulaire a besoin.
class Site {
  const Site({required this.id, required this.name});

  final String id;
  final String name;

  factory Site.fromJson(Map<String, dynamic> j) => Site(id: j['id'] as String, name: j['name'] as String);
}
```

`lib/features/directory/directory_repository.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/paged.dart';
import 'directory_model.dart';

/// Routes `/directories` du backend.
class DirectoryRepository {
  DirectoryRepository(this._api);
  final ApiClient _api;

  Future<Paged<Directory>> list(String accessToken, {int limit = 100, int offset = 0}) async {
    final data =
        await _api.get('/directories', accessToken: accessToken, query: {'limit': '$limit', 'offset': '$offset'});
    return Paged.fromJson(data as Map<String, dynamic>, Directory.fromJson);
  }

  /// Site principal d'abord, puis les annexes par nom.
  Future<List<Site>> sites(String accessToken, String directoryId) async {
    final data = await _api.get('/directories/$directoryId/sites', accessToken: accessToken);
    return (data as List).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final directoryRepositoryProvider = Provider((ref) => DirectoryRepository(ref.watch(apiClientProvider)));
```

`lib/features/auth/session_provider.dart` — ajouter à la fin du fichier :

```dart
/// Jeton valide pour un appel API ; lève une [ApiException] 401 quand la session est terminée
/// (main.dart renvoie alors vers la connexion).
Future<String> requireAccessToken(Ref ref) async {
  final token = await ref.read(sessionProvider.notifier).accessToken();
  if (token == null) throw ApiException('Session expirée, reconnectez-vous.', status: 401);
  return token;
}
```

Supprimer : `git rm lib/features/employee/employee_screen.dart lib/features/employee/employee_controller.dart`.

- [ ] **Step 4 : vérifier** — `flutter test` → PASSE ; `flutter analyze` → aucun problème.

- [ ] **Step 5 : commit**

```bash
git add lib/features test/features
git commit -m "feat(employee): align models and repositories with the backend contract

Employee no longer expects directoryId (not returned), list returns a typed
page, and user/directory modules expose what the creation form needs.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : `EmployeeController` (liste partagée web/mobile)

**Files :**
- Create: `lib/features/employee/employee_controller.dart`
- Create: `test/helpers/fakes.dart`
- Test: `test/features/employee/unit/employee_controller_test.dart`

**Interfaces :**
- Consumes : `EmployeeRepository`, `EmployeeFilters`, `requireAccessToken`.
- Produces :
  - `EmployeeState` : `items`, `total`, `offset`, `filters`, `loading`, `loadingMore`, `error` ; `static const limit = 20` ; `hasMore`, `page`, `pageCount`
  - `EmployeeController` : `refresh()`, `setFilters(EmployeeFilters)`, `goToPage(int)`, `loadMore()` → `Future<void>`
  - `employeeControllerProvider` ; `String employeeErrorMessage(Object e)`
  - Helpers de test : `FakeSession`, `Override fakeSession({String? token = 'tok'})`, `Employee fakeEmployee(int n, {Role role, bool isActive})`, `FakeEmployeeRepository([List<Employee>? all])` (champs `all`, `calls`, `listError`, `beforeReturn`, `createError`, `lastDraft`)

- [ ] **Step 1 : helpers de test** — `test/helpers/fakes.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/paged.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/auth/session_provider.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';

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
```

- [ ] **Step 2 : écrire les tests qui échouent** — `test/features/employee/unit/employee_controller_test.dart`

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/employee/employee_controller.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeEmployeeRepository repo;
  late ProviderContainer container;
  EmployeeController controller() => container.read(employeeControllerProvider.notifier);
  EmployeeState state() => container.read(employeeControllerProvider);

  void setUpWith({String? token = 'tok', FakeEmployeeRepository? repository}) {
    repo = repository ?? FakeEmployeeRepository();
    container = ProviderContainer.test(
      overrides: [fakeSession(token: token), employeeRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
  }

  test('refresh loads the first page', () async {
    setUpWith();
    await controller().refresh();
    expect(state().items.map((e) => e.id).take(2), ['emp1', 'emp2']);
    expect((state().items.length, state().total, state().offset, state().loading), (20, 45, 0, false));
    expect(state().hasMore, isTrue);
  });

  test('goToPage replaces the items with that page', () async {
    setUpWith();
    await controller().refresh();
    await controller().goToPage(2);
    expect(state().items.map((e) => e.id), ['emp41', 'emp42', 'emp43', 'emp44', 'emp45']);
    expect((state().offset, state().page, state().pageCount, state().hasMore), (40, 2, 3, false));
  });

  test('goToPage outside the pages does nothing', () async {
    setUpWith();
    await controller().refresh();
    await controller().goToPage(3);
    await controller().goToPage(-1);
    expect(repo.calls, hasLength(1));
  });

  test('setFilters sends the filters and starts again from the first page', () async {
    setUpWith();
    await controller().refresh();
    await controller().goToPage(1);
    await controller().setFilters(const EmployeeFilters(isActive: true, role: Role.employee));
    expect(repo.calls.last.offset, 0);
    expect(repo.calls.last.filters.role, Role.employee);
    expect(state().offset, 0);
  });

  test('loadMore appends the next page and stops when everything is loaded', () async {
    setUpWith();
    await controller().refresh();
    await controller().loadMore();
    expect((state().items.length, state().offset), (40, 0));
    await controller().loadMore();
    expect(state().items.length, 45);
    await controller().loadMore();
    expect(repo.calls, hasLength(3));
    expect(state().hasMore, isFalse);
  });

  test('loadMore ignores a second call while the first is running', () async {
    setUpWith();
    await controller().refresh();
    await Future.wait([controller().loadMore(), controller().loadMore()]);
    expect(repo.calls, hasLength(2));
    expect(state().items.length, 40);
  });

  test('a failure keeps a readable message, the next refresh clears it', () async {
    setUpWith();
    repo.listError = ApiException('Erreur serveur (500)', status: 500);
    await controller().refresh();
    expect((state().error, state().loading, state().items), ('Erreur serveur (500)', false, isEmpty));
    repo.listError = null;
    await controller().refresh();
    expect(state().error, isNull);
    expect(state().items, hasLength(20));
  });

  test('an older response arriving after a newer one is ignored', () async {
    setUpWith();
    final first = Completer<void>();
    repo.beforeReturn = (call) => call == 0 ? first.future : Future.value();
    final slow = controller().setFilters(const EmployeeFilters(role: Role.manager));
    await controller().setFilters(const EmployeeFilters());
    first.complete();
    await slow;
    expect(state().filters.role, isNull);
    expect(state().total, 45);
  });

  test('refresh on a page that no longer exists falls back to the last page', () async {
    setUpWith();
    await controller().refresh();
    await controller().goToPage(2);
    repo.all.removeRange(30, 45); // il reste 30 employés : 2 pages
    await controller().refresh();
    expect((state().offset, state().items.length, state().total), (20, 10, 30));
  });

  test('an ended session stops loading with an explicit message', () async {
    setUpWith(token: null);
    await controller().refresh();
    expect(repo.calls, isEmpty);
    expect(state().loading, isFalse);
    expect(state().error, 'Session expirée, reconnectez-vous.');
  });

  test('employeeErrorMessage', () {
    expect(employeeErrorMessage(ApiException('x', status: 404)), 'Employé introuvable.');
    expect(employeeErrorMessage(ApiException('Ce matricule est déjà utilisé.', status: 409)), 'Ce matricule est déjà utilisé.');
    expect(employeeErrorMessage(TimeoutException('t')), 'Connexion au serveur impossible, réessayez.');
  });
}
```

- [ ] **Step 3 : vérifier l'échec** — `flutter test test/features/employee/unit/employee_controller_test.dart` → ÉCHEC (fichier manquant).

- [ ] **Step 4 : implémenter** — `lib/features/employee/employee_controller.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/session_provider.dart';
import 'employee_model.dart';
import 'employee_repository.dart';

/// Message affiché pour une erreur du module.
String employeeErrorMessage(Object e) => switch (e) {
      ApiException(status: 404) => 'Employé introuvable.',
      ApiException(:final message) => message,
      _ => 'Connexion au serveur impossible, réessayez.',
    };

class EmployeeState {
  const EmployeeState({
    this.items = const [],
    this.total = 0,
    this.offset = 0,
    this.filters = const EmployeeFilters(),
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  static const limit = 20;

  /// Fenêtre affichée : de [offset] à `offset + items.length`, sur [total].
  /// Le web remplace la fenêtre page par page ; le mobile l'allonge ([offset] reste 0).
  final List<Employee> items;
  final int total;
  final int offset;
  final EmployeeFilters filters;
  final bool loading;
  final bool loadingMore;
  final String? error;

  bool get hasMore => offset + items.length < total;
  int get page => offset ~/ limit;
  int get pageCount => total == 0 ? 1 : (total + limit - 1) ~/ limit;

  /// [error] n'est pas recopié : un nouvel état l'efface, sauf s'il est fourni.
  EmployeeState copyWith({
    List<Employee>? items,
    int? total,
    int? offset,
    EmployeeFilters? filters,
    bool? loading,
    bool? loadingMore,
    String? error,
  }) =>
      EmployeeState(
        items: items ?? this.items,
        total: total ?? this.total,
        offset: offset ?? this.offset,
        filters: filters ?? this.filters,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
      );
}

/// Liste des employés, partagée par l'écran web (pages) et l'écran mobile (défilement infini).
class EmployeeController extends Notifier<EmployeeState> {
  /// Numéro de la dernière requête lancée : toute réponse plus ancienne est ignorée.
  int _generation = 0;

  @override
  EmployeeState build() {
    ref.watch(sessionProvider.select((s) => s.value?.identifier)); // repart à zéro quand l'utilisateur change
    return const EmployeeState();
  }

  Future<void> refresh() => _fetch(state.offset);

  Future<void> setFilters(EmployeeFilters filters) {
    state = state.copyWith(filters: filters);
    return _fetch(0);
  }

  Future<void> goToPage(int page) async {
    if (page < 0 || page >= state.pageCount) return;
    await _fetch(page * EmployeeState.limit);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final generation = _generation;
    final filters = state.filters;
    final next = state.offset + state.items.length;
    state = state.copyWith(loadingMore: true);
    try {
      final token = await requireAccessToken(ref);
      final page = await ref
          .read(employeeRepositoryProvider)
          .list(token, filters: filters, limit: EmployeeState.limit, offset: next);
      if (!_isCurrent(generation)) return;
      state = state.copyWith(items: [...state.items, ...page.items], total: page.total, loadingMore: false);
    } catch (e) {
      if (_isCurrent(generation)) state = state.copyWith(loadingMore: false, error: employeeErrorMessage(e));
    }
  }

  Future<void> _fetch(int offset) async {
    final generation = ++_generation;
    final filters = state.filters;
    state = state.copyWith(loading: true, loadingMore: false);
    try {
      final token = await requireAccessToken(ref);
      final page = await ref
          .read(employeeRepositoryProvider)
          .list(token, filters: filters, limit: EmployeeState.limit, offset: offset);
      if (!_isCurrent(generation)) return;
      // La page demandée n'existe plus (le total a baissé) : on revient à la dernière.
      if (page.items.isEmpty && offset > 0 && page.total > 0) {
        return _fetch((page.total - 1) ~/ EmployeeState.limit * EmployeeState.limit);
      }
      state = state.copyWith(items: page.items, total: page.total, offset: offset, loading: false);
    } catch (e) {
      if (_isCurrent(generation)) state = state.copyWith(loading: false, error: employeeErrorMessage(e));
    }
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final employeeControllerProvider = NotifierProvider<EmployeeController, EmployeeState>(EmployeeController.new);
```

- [ ] **Step 5 : vérifier** — `flutter test` → PASSE ; `flutter analyze` → aucun problème.

- [ ] **Step 6 : commit**

```bash
git add lib/features/employee/employee_controller.dart test/helpers test/features/employee/unit/employee_controller_test.dart
git commit -m "feat(employee): add the shared list controller (pages and infinite scroll)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7 : détail, formulaire et listes de choix

**Files :**
- Modify: `lib/features/employee/employee_controller.dart` (ajouts en fin de fichier)
- Create: `lib/features/user/user_controller.dart`, `lib/features/directory/directory_controller.dart`
- Modify: `test/helpers/fakes.dart` (ajout de `FakeUserRepository`, `FakeDirectoryRepository`)
- Test: `test/features/employee/unit/employee_form_controller_test.dart`, `test/features/employee/unit/employee_detail_provider_test.dart`, `test/features/user/unit/user_controller_test.dart`, `test/features/directory/unit/directory_controller_test.dart`

**Interfaces :**
- Produces :
  - `employeeDetailProvider` : `FutureProvider.autoDispose.family<Employee, String>`
  - `EmployeeFormState({bool submitting = false, String? error})` ; `EmployeeFormController.submit(EmployeeDraft) → Future<Employee?>` (null en cas d'échec, message dans l'état) ; `employeeFormControllerProvider` (autoDispose)
  - `allUsersProvider` : `FutureProvider.autoDispose<List<AppUser>>`
  - `allDirectoriesProvider` : `FutureProvider.autoDispose<List<Directory>>` ; `directorySitesProvider` : `FutureProvider.autoDispose.family<List<Site>, String>`
  - Fakes : `FakeUserRepository({List<AppUser>? users, Object? error})`, `FakeDirectoryRepository({List<Directory>? directories, Map<String, List<Site>>? sites, Object? error})`, `const ana = AppUser(...)`, `const direction = Directory(...)`, `const siege = Site(...)`

- [ ] **Step 1 : compléter les fakes** — ajouter à `test/helpers/fakes.dart` (avec les imports `user_model.dart`, `user_repository.dart`, `directory_model.dart`, `directory_repository.dart`) :

```dart
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
```

- [ ] **Step 2 : écrire les tests qui échouent**

`test/features/employee/unit/employee_form_controller_test.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/employee/employee_controller.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';

import '../../../helpers/fakes.dart';

const draft = EmployeeDraft(userId: 'usr1', directoryId: 'dir1', employeeNumber: 'EMP0000099');

void main() {
  late FakeEmployeeRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeEmployeeRepository();
    container = ProviderContainer.test(
      overrides: [fakeSession(), employeeRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
    container.listen(employeeFormControllerProvider, (_, _) {}); // garde le provider autoDispose en vie
  });

  test('a successful submit returns the employee and refreshes the list', () async {
    final created = await container.read(employeeFormControllerProvider.notifier).submit(draft);
    expect(created?.employeeNumber, 'EMP0000099');
    expect(repo.lastDraft, same(draft));
    expect(container.read(employeeFormControllerProvider).submitting, isFalse);
    expect(container.read(employeeFormControllerProvider).error, isNull);
    await pumpEventQueue();
    expect(repo.calls, isNotEmpty);
  });

  test('a rejected submit returns null and keeps the backend message', () async {
    repo.createError = ApiException('Ce matricule est déjà utilisé.', status: 409);
    final created = await container.read(employeeFormControllerProvider.notifier).submit(draft);
    expect(created, isNull);
    expect(container.read(employeeFormControllerProvider).error, 'Ce matricule est déjà utilisé.');
    expect(container.read(employeeFormControllerProvider).submitting, isFalse);
  });

  test('a network failure gives a creation-specific message', () async {
    repo.createError = Exception('socket');
    await container.read(employeeFormControllerProvider.notifier).submit(draft);
    expect(container.read(employeeFormControllerProvider).error, 'Création impossible, vérifiez la connexion.');
  });
}
```

`test/features/employee/unit/employee_detail_provider_test.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/employee/employee_controller.dart';
import 'package:pointage/features/employee/employee_repository.dart';

import '../../../helpers/fakes.dart';

void main() {
  ProviderContainer containerWith(FakeEmployeeRepository repo) => ProviderContainer.test(
        overrides: [fakeSession(), employeeRepositoryProvider.overrideWithValue(repo)],
        retry: (_, _) => null,
      );

  test('loads one employee', () async {
    final container = containerWith(FakeEmployeeRepository());
    final sub = container.listen(employeeDetailProvider('emp3'), (_, _) {});
    expect((await container.read(employeeDetailProvider('emp3').future)).employeeNumber, 'EMP0000003');
    sub.close();
  });

  test('an unknown id fails with the "not found" message', () async {
    final container = containerWith(FakeEmployeeRepository());
    final sub = container.listen(employeeDetailProvider('emp999'), (_, _) {});
    final error = await container.read(employeeDetailProvider('emp999').future).then<Object?>((_) => null, onError: (Object e) => e);
    expect(employeeErrorMessage(error!), 'Employé introuvable.');
    sub.close();
  });
}
```

`test/features/user/unit/user_controller_test.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/user/user_controller.dart';
import 'package:pointage/features/user/user_repository.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('allUsersProvider lists the accounts', () async {
    final container = ProviderContainer.test(
      overrides: [fakeSession(), userRepositoryProvider.overrideWithValue(FakeUserRepository())],
      retry: (_, _) => null,
    );
    final sub = container.listen(allUsersProvider, (_, _) {});
    expect((await container.read(allUsersProvider.future)).single.id, 'usr1');
    sub.close();
  });
}
```

`test/features/directory/unit/directory_controller_test.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/directory/directory_controller.dart';
import 'package:pointage/features/directory/directory_repository.dart';

import '../../../helpers/fakes.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer.test(
        overrides: [fakeSession(), directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository())],
        retry: (_, _) => null,
      ));

  test('allDirectoriesProvider lists the directories', () async {
    final sub = container.listen(allDirectoriesProvider, (_, _) {});
    expect((await container.read(allDirectoriesProvider.future)).single.code, 'DG');
    sub.close();
  });

  test('directorySitesProvider lists the sites of one directory', () async {
    final sub = container.listen(directorySitesProvider('dir1'), (_, _) {});
    expect((await container.read(directorySitesProvider('dir1').future)).single.name, 'Siège Cotonou');
    sub.close();
  });
}
```

- [ ] **Step 3 : vérifier l'échec** — `flutter test test/features` → ÉCHEC (providers manquants).

- [ ] **Step 4 : implémenter**

Ajouter à la fin de `lib/features/employee/employee_controller.dart` (et ajouter `import 'dart:async';` en tête du fichier pour `unawaited`) :

```dart
/// Fiche d'un employé (`GET /employees/{id}`). Pas de nouvel essai automatique :
/// un 404 doit s'afficher tout de suite.
final employeeDetailProvider = FutureProvider.autoDispose.family<Employee, String>(
  (ref, id) async => ref.read(employeeRepositoryProvider).getById(await requireAccessToken(ref), id),
  retry: (_, _) => null,
);

class EmployeeFormState {
  const EmployeeFormState({this.submitting = false, this.error});
  final bool submitting;
  final String? error;
}

/// Création d'un employé ; rafraîchit la liste après succès.
class EmployeeFormController extends Notifier<EmployeeFormState> {
  @override
  EmployeeFormState build() => const EmployeeFormState();

  /// L'employé créé, ou null en cas d'échec (le message est dans l'état).
  Future<Employee?> submit(EmployeeDraft draft) async {
    if (state.submitting) return null;
    state = const EmployeeFormState(submitting: true);
    try {
      final created = await ref.read(employeeRepositoryProvider).create(await requireAccessToken(ref), draft);
      if (ref.mounted) state = const EmployeeFormState();
      unawaited(ref.read(employeeControllerProvider.notifier).refresh());
      return created;
    } catch (e) {
      if (ref.mounted) {
        state = EmployeeFormState(
          error: e is ApiException ? e.message : 'Création impossible, vérifiez la connexion.',
        );
      }
      return null;
    }
  }
}

final employeeFormControllerProvider =
    NotifierProvider.autoDispose<EmployeeFormController, EmployeeFormState>(EmployeeFormController.new);
```

`lib/features/user/user_controller.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_provider.dart';
import 'user_model.dart';
import 'user_repository.dart';

/// Comptes proposés dans le formulaire de création d'employé (les 100 premiers).
final allUsersProvider = FutureProvider.autoDispose<List<AppUser>>(
  (ref) async => (await ref.read(userRepositoryProvider).list(await requireAccessToken(ref))).items,
  retry: (_, _) => null,
);
```

`lib/features/directory/directory_controller.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_provider.dart';
import 'directory_model.dart';
import 'directory_repository.dart';

/// Annuaires proposés dans le formulaire de création d'employé (les 100 premiers).
final allDirectoriesProvider = FutureProvider.autoDispose<List<Directory>>(
  (ref) async => (await ref.read(directoryRepositoryProvider).list(await requireAccessToken(ref))).items,
  retry: (_, _) => null,
);

/// Sites d'un annuaire, site principal en premier.
final directorySitesProvider = FutureProvider.autoDispose.family<List<Site>, String>(
  (ref, directoryId) async => ref.read(directoryRepositoryProvider).sites(await requireAccessToken(ref), directoryId),
  retry: (_, _) => null,
);
```

- [ ] **Step 5 : vérifier** — `flutter test` → PASSE ; `flutter analyze` → aucun problème.

- [ ] **Step 6 : commit**

```bash
git add lib/features test/helpers test/features
git commit -m "feat(employee): add detail, creation and option providers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Partie C — Frontend : mise en page adaptative

### Task 8 : `Breakpoints`, `NavItem`, `AdminShell`, `MobileShell`

**Files :**
- Create: `lib/core/layout/breakpoints.dart`, `lib/core/layout/nav_item.dart`, `lib/core/layout/admin_shell.dart`, `lib/core/layout/mobile_shell.dart`
- Create: `test/helpers/pump.dart`
- Test: `test/core/unit/breakpoints_test.dart`, `test/core/widget/admin_shell_test.dart`, `test/core/widget/mobile_shell_test.dart`

**Interfaces :**
- Produces :
  - `enum WindowSize { compact, medium, expanded }` ; `Breakpoints.medium = 600`, `Breakpoints.expanded = 1024`, `Breakpoints.fromWidth(double) → WindowSize`, `Breakpoints.of(BuildContext) → WindowSize` (largeur de la fenêtre)
  - `NavItem({required String label, required IconData icon, required WidgetBuilder builder})`
  - `AdminShell({required List<NavItem> menus})` ; `adminMenuIndexProvider` ; clés de test `Key('admin-side-menu')`, `Key('admin-rail')`
  - `MobileShell({required List<NavItem> tabs})` (au moins 2 onglets)
  - Helper `pumpAtWidth(WidgetTester, double width, Widget child, {double height = 900, List<Override> overrides = const [], bool settle = true})`

- [ ] **Step 1 : helper de test** — `test/helpers/pump.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/theme.dart';

/// Largeurs de référence de la responsivité web : téléphone, tablette, desktop.
const responsiveWidths = [360.0, 800.0, 1440.0];

/// Affiche [child] dans une fenêtre de [width] × [height] px. Les débordements
/// (RenderFlex overflowed) font échouer le test automatiquement.
/// Thème sans Google Fonts : pas d'accès réseau en test.
Future<void> pumpAtWidth(
  WidgetTester tester,
  double width,
  Widget child, {
  double height = 900,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    retry: (_, _) => null,
    child: MaterialApp(theme: ThemeData(colorSchemeSeed: AppColors.green), home: child),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
```

- [ ] **Step 2 : écrire les tests qui échouent**

`test/core/unit/breakpoints_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/layout/breakpoints.dart';

void main() {
  test('window sizes switch exactly at 600 and 1024 px', () {
    expect(Breakpoints.fromWidth(599), WindowSize.compact);
    expect(Breakpoints.fromWidth(600), WindowSize.medium);
    expect(Breakpoints.fromWidth(1023), WindowSize.medium);
    expect(Breakpoints.fromWidth(1024), WindowSize.expanded);
  });
}
```

`test/core/widget/admin_shell_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/layout/admin_shell.dart';
import 'package:pointage/core/layout/nav_item.dart';
import 'package:pointage/features/auth/session_provider.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

final menus = [
  NavItem(label: 'Menu A', icon: Icons.badge_outlined, builder: (_) => const Text('Page A')),
  NavItem(label: 'Menu B', icon: Icons.schedule, builder: (_) => const Text('Page B')),
];

Future<void> pumpShell(WidgetTester tester, double width, {List<NavItem>? items}) =>
    pumpAtWidth(tester, width, AdminShell(menus: items ?? menus), overrides: [fakeSession()]);

void main() {
  testWidgets('phone: app bar with a drawer', (tester) async {
    await pumpShell(tester, 360);
    expect(find.text('Page A'), findsOneWidget);
    expect(find.byKey(const Key('admin-side-menu')), findsNothing);
    expect(find.byKey(const Key('admin-rail')), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menu B'));
    await tester.pumpAndSettle();
    expect(find.text('Page B'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Menu B'), findsOneWidget);
  });

  testWidgets('tablet: icon rail with tooltips', (tester) async {
    await pumpShell(tester, 800);
    expect(find.byKey(const Key('admin-rail')), findsOneWidget);
    expect(find.byKey(const Key('admin-side-menu')), findsNothing);
    await tester.tap(find.byTooltip('Menu B'));
    await tester.pumpAndSettle();
    expect(find.text('Page B'), findsOneWidget);
  });

  testWidgets('desktop: side menu with labels', (tester) async {
    await pumpShell(tester, 1440);
    expect(find.byKey(const Key('admin-side-menu')), findsOneWidget);
    await tester.tap(find.text('Menu B'));
    await tester.pumpAndSettle();
    expect(find.text('Page B'), findsOneWidget);
  });

  testWidgets('a single menu works at every width', (tester) async {
    for (final width in responsiveWidths) {
      await pumpShell(tester, width, items: [menus.first]);
      expect(find.text('Page A'), findsOneWidget, reason: '$width px');
      expect(tester.takeException(), isNull, reason: '$width px');
    }
  });

  testWidgets('desktop: logout ends the session', (tester) async {
    await pumpShell(tester, 1440);
    await tester.tap(find.byTooltip('Se déconnecter'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(AdminShell)));
    expect(container.read(sessionProvider).value, isNull);
  });

  testWidgets('content is capped at 1400 px on very wide screens', (tester) async {
    await pumpAtWidth(tester, 2400, AdminShell(menus: menus), overrides: [fakeSession()]);
    final page = tester.getRect(find.byKey(const Key('admin-page')));
    expect(page.width, lessThanOrEqualTo(1400));
  });
}
```

`test/core/widget/mobile_shell_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/layout/mobile_shell.dart';
import 'package:pointage/core/layout/nav_item.dart';

import '../../helpers/pump.dart';

void main() {
  testWidgets('bottom bar switches tabs and builds a tab only once visited', (tester) async {
    await pumpAtWidth(
      tester,
      390,
      MobileShell(tabs: [
        NavItem(label: 'Pointage', icon: Icons.fingerprint, builder: (_) => const Text('Page pointage')),
        NavItem(label: 'Employés', icon: Icons.badge_outlined, builder: (_) => const Text('Page employés')),
      ]),
      height: 800,
    );
    expect(find.text('Page pointage'), findsOneWidget);
    expect(find.text('Page employés', skipOffstage: false), findsNothing);
    await tester.tap(find.text('Employés'));
    await tester.pumpAndSettle();
    expect(find.text('Page employés'), findsOneWidget);
  });
}
```

- [ ] **Step 3 : vérifier l'échec** — `flutter test test/core` → ÉCHEC (fichiers manquants).

- [ ] **Step 4 : implémenter**

`lib/core/layout/breakpoints.dart`

```dart
import 'package:flutter/widgets.dart';

enum WindowSize { compact, medium, expanded }

/// Points de rupture communs à tous les écrans.
/// Utiliser [of] pour la fenêtre (navigation), [fromWidth] avec un `LayoutBuilder`
/// pour la place réellement disponible (contenu).
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 1024.0;

  static WindowSize fromWidth(double width) => width >= expanded
      ? WindowSize.expanded
      : width >= medium
          ? WindowSize.medium
          : WindowSize.compact;

  static WindowSize of(BuildContext context) => fromWidth(MediaQuery.sizeOf(context).width);
}
```

`lib/core/layout/nav_item.dart`

```dart
import 'package:flutter/widgets.dart';

/// Une entrée de navigation : un menu de l'admin ou un onglet du mobile.
class NavItem {
  const NavItem({required this.label, required this.icon, required this.builder});

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}
```

`lib/core/layout/admin_shell.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/session_provider.dart';
import '../theme.dart';
import 'breakpoints.dart';
import 'nav_item.dart';

/// Menu affiché dans le back-office.
class AdminMenuIndex extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final adminMenuIndexProvider = NotifierProvider<AdminMenuIndex, int>(AdminMenuIndex.new);

/// Coquille du back-office : menu latéral (≥ 1024 px), rail d'icônes (600–1023 px)
/// ou tiroir (< 600 px). Ajouter un menu = ajouter un [NavItem] à [menus].
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.menus}) : assert(menus.length > 0);

  final List<NavItem> menus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = Breakpoints.of(context);
    final index = ref.watch(adminMenuIndexProvider).clamp(0, menus.length - 1);
    final identifier = ref.watch(sessionProvider).value?.identifier ?? '';
    void select(int i) => ref.read(adminMenuIndexProvider.notifier).select(i);
    void logout() => ref.read(sessionProvider.notifier).logout();
    final page = _Page(size: size, child: KeyedSubtree(key: ValueKey(index), child: Builder(builder: menus[index].builder)));

    if (size == WindowSize.compact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(menus[index].label),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(4), child: FlagStripe()),
        ),
        drawer: NavigationDrawer(
          selectedIndex: index,
          onDestinationSelected: (i) {
            Navigator.of(context).pop(); // referme le tiroir
            select(i);
          },
          children: [
            const _Brand(),
            for (final m in menus) NavigationDrawerDestination(icon: Icon(m.icon), label: Text(m.label)),
            const Divider(indent: 28, endIndent: 28),
            _UserTile(identifier: identifier, onLogout: logout),
          ],
        ),
        body: page,
      );
    }

    final navigation = size == WindowSize.expanded
        ? _SideMenu(menus: menus, index: index, onSelect: select, identifier: identifier, onLogout: logout)
        : _Rail(menus: menus, index: index, onSelect: select, onLogout: logout);
    return Scaffold(
      body: Column(children: [
        const FlagStripe(),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            navigation,
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ]),
        ),
      ]),
    );
  }
}

/// Zone de contenu : 1400 px au plus, marges de 16 px (téléphone) ou 24 px.
class _Page extends StatelessWidget {
  const _Page({required this.size, required this.child});
  final WindowSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SizedBox.expand(
            key: const Key('admin-page'),
            child: Padding(padding: EdgeInsets.all(size == WindowSize.compact ? 16 : 24), child: child),
          ),
        ),
      );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
        child: Row(children: [
          const Icon(Icons.fingerprint, color: AppColors.green, size: 28),
          const SizedBox(width: 12),
          Flexible(
            child: Text('Pointage',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ]),
      );
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.identifier, required this.onLogout});
  final String identifier;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(identifier, overflow: TextOverflow.ellipsis),
        trailing: IconButton(tooltip: 'Se déconnecter', icon: const Icon(Icons.logout), onPressed: onLogout),
      );
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.menus,
    required this.index,
    required this.onSelect,
    required this.identifier,
    required this.onLogout,
  });

  final List<NavItem> menus;
  final int index;
  final ValueChanged<int> onSelect;
  final String identifier;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => SizedBox(
        key: const Key('admin-side-menu'),
        width: 240,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _Brand(),
            Expanded(
              child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                for (var i = 0; i < menus.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      selected: i == index,
                      selectedColor: AppColors.green,
                      selectedTileColor: AppColors.green.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(menus[i].icon),
                      title: Text(menus[i].label, overflow: TextOverflow.ellipsis),
                      onTap: () => onSelect(i),
                    ),
                  ),
              ]),
            ),
            const Divider(height: 1),
            _UserTile(identifier: identifier, onLogout: onLogout),
          ]),
        ),
      );
}

/// Rail d'icônes maison : `NavigationRail` exige au moins deux destinations,
/// or l'admin peut n'avoir qu'un menu.
class _Rail extends StatelessWidget {
  const _Rail({required this.menus, required this.index, required this.onSelect, required this.onLogout});

  final List<NavItem> menus;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => SizedBox(
        key: const Key('admin-rail'),
        width: 80,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(children: [
            const SizedBox(height: 16),
            const Icon(Icons.fingerprint, color: AppColors.green, size: 32),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(children: [
                for (var i = 0; i < menus.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: i == index
                          ? IconButton.filledTonal(
                              tooltip: menus[i].label, icon: Icon(menus[i].icon), onPressed: () => onSelect(i))
                          : IconButton(tooltip: menus[i].label, icon: Icon(menus[i].icon), onPressed: () => onSelect(i)),
                    ),
                  ),
              ]),
            ),
            IconButton(tooltip: 'Se déconnecter', icon: const Icon(Icons.logout), onPressed: onLogout),
            const SizedBox(height: 16),
          ]),
        ),
      );
}
```

`lib/core/layout/mobile_shell.dart`

```dart
import 'package:flutter/material.dart';

import 'nav_item.dart';

/// Coquille de l'app mobile : barre de navigation en bas.
/// Un onglet n'est construit qu'à sa première visite, puis reste en vie.
class MobileShell extends StatefulWidget {
  const MobileShell({super.key, required this.tabs}) : assert(tabs.length >= 2, 'NavigationBar exige 2 onglets');

  final List<NavItem> tabs;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _index = 0;
  final _visited = <int>{0};

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: [
          for (var i = 0; i < widget.tabs.length; i++)
            _visited.contains(i) ? Builder(builder: widget.tabs[i].builder) : const SizedBox.shrink(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() {
            _index = i;
            _visited.add(i);
          }),
          destinations: [
            for (final t in widget.tabs) NavigationDestination(icon: Icon(t.icon), label: t.label),
          ],
        ),
      );
}
```

- [ ] **Step 5 : vérifier** — `flutter test test/core` → PASSE ; `flutter analyze` → aucun problème.

- [ ] **Step 6 : commit**

```bash
git add lib/core/layout test/helpers/pump.dart test/core
git commit -m "feat(layout): add responsive admin shell and mobile shell

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9 : widgets communs et widgets d'affichage Employés

**Files :**
- Create: `lib/core/widgets/state_views.dart`, `lib/core/widgets/pagination_bar.dart`, `lib/core/widgets/search_field.dart`
- Create: `lib/features/employee/widgets/employee_badges.dart`, `employee_card.dart`, `employee_table.dart`, `employee_filter_fields.dart`, `employee_toolbar.dart`, `employee_detail_view.dart`
- Test: `test/core/widget/core_widgets_test.dart`, `test/features/employee/widget/employee_widgets_test.dart`, `test/features/employee/widget/employee_detail_view_test.dart`

**Interfaces :**
- Produces :
  - `EmptyState({required IconData icon, required String message})`, `ErrorState({required String message, required VoidCallback onRetry})`
  - `PaginationBar({required int offset, required int count, required int total, VoidCallback? onPrevious, VoidCallback? onNext})` (tooltips `Page précédente` / `Page suivante`)
  - `SearchField({required String label, required ValueChanged<String> onChanged, String initialValue = '', Duration debounce = 300 ms})`
  - `RoleBadge({required Role role})`, `StatusPill({required bool isActive})`
  - `EmployeeCard({required Employee employee, required VoidCallback onTap})`
  - `EmployeeTable({required List<Employee> employees, required ValueChanged<Employee> onTap, bool showCreatedAt = true, String? selectedId})`
  - `RoleFilterField({required Role? value, required ValueChanged<Role?> onChanged, double? width})`, `StatusFilterField({required bool? value, required ValueChanged<bool?> onChanged, double? width})`
  - `EmployeeToolbar({required EmployeeFilters filters, required ValueChanged<EmployeeFilters> onChanged, required VoidCallback onCreate, bool compact = false})`
  - `EmployeeDetailView({required String id})`, `EmployeeDetailPanel({required String id, required VoidCallback onClose})`

- [ ] **Step 1 : écrire les tests qui échouent**

`test/core/widget/core_widgets_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/widgets/pagination_bar.dart';
import 'package:pointage/core/widgets/search_field.dart';
import 'package:pointage/core/widgets/state_views.dart';

import '../../helpers/pump.dart';

void main() {
  testWidgets('PaginationBar shows the range and disables missing directions', (tester) async {
    var next = 0;
    await pumpAtWidth(tester, 360, Scaffold(body: PaginationBar(offset: 20, count: 20, total: 45, onNext: () => next++)));
    expect(find.text('21–40 sur 45'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left)).onPressed, isNull);
    await tester.tap(find.byTooltip('Page suivante'));
    expect(next, 1);
  });

  testWidgets('SearchField waits 300 ms of silence, then sends the trimmed text once', (tester) async {
    final sent = <String>[];
    await pumpAtWidth(tester, 360, Scaffold(body: SearchField(label: 'Matricule', onChanged: sent.add)));
    await tester.enterText(find.byType(TextField), 'EMP');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), ' EMP0000001 ');
    await tester.pump(const Duration(milliseconds: 299));
    expect(sent, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(sent, ['EMP0000001']);
  });

  testWidgets('ErrorState offers a retry', (tester) async {
    var retried = false;
    await pumpAtWidth(tester, 360, Scaffold(body: ErrorState(message: 'Boom', onRetry: () => retried = true)));
    await tester.tap(find.text('Réessayer'));
    expect(retried, isTrue);
  });

  testWidgets('state views fit in a very short area', (tester) async {
    await pumpAtWidth(
      tester,
      360,
      Scaffold(body: SizedBox(height: 80, child: ErrorState(message: 'Boom', onRetry: () {}))),
    );
    expect(tester.takeException(), isNull);
  });
}
```

`test/features/employee/widget/employee_widgets_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/widgets/employee_card.dart';
import 'package:pointage/features/employee/widgets/employee_table.dart';
import 'package:pointage/features/employee/widgets/employee_toolbar.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  testWidgets('EmployeeTable shows "Créé le" only when asked, and reports taps', (tester) async {
    Employee? tapped;
    final employees = [fakeEmployee(1), fakeEmployee(2, role: Role.manager, isActive: false)];
    await pumpAtWidth(tester, 800, Scaffold(body: EmployeeTable(employees: employees, onTap: (e) => tapped = e)));
    expect(find.text('Créé le'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('Inactif'), findsOneWidget);
    await tester.tap(find.text('EMP0000002'));
    expect(tapped?.id, 'emp2');

    await pumpAtWidth(tester, 800, Scaffold(body: EmployeeTable(employees: employees, onTap: (_) {}, showCreatedAt: false)));
    expect(find.text('Créé le'), findsNothing);
  });

  testWidgets('EmployeeCard shows number, role and status within a phone width', (tester) async {
    await pumpAtWidth(tester, 320, Scaffold(body: EmployeeCard(employee: fakeEmployee(1), onTap: () {})));
    expect(find.text('EMP0000001'), findsOneWidget);
    expect(find.text('Employé'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
  });

  testWidgets('EmployeeToolbar keeps the other criteria when one changes', (tester) async {
    EmployeeFilters? sent;
    await pumpAtWidth(
      tester,
      1200,
      Scaffold(
        body: EmployeeToolbar(
          filters: const EmployeeFilters(search: 'EMP0000001', isActive: true),
          onChanged: (f) => sent = f,
          onCreate: () {},
        ),
      ),
    );
    await tester.tap(find.text('Tous les rôles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RH').last);
    await tester.pumpAndSettle();
    expect((sent?.search, sent?.role, sent?.isActive), ('EMP0000001', Role.hr, true));
    expect(find.text('Nouvel employé'), findsOneWidget);
  });

  testWidgets('EmployeeToolbar compact: full-width fields and an icon button', (tester) async {
    await pumpAtWidth(
      tester,
      360,
      Scaffold(body: EmployeeToolbar(filters: const EmployeeFilters(), onChanged: (_) {}, onCreate: () {}, compact: true)),
    );
    expect(find.byTooltip('Nouvel employé'), findsOneWidget);
    expect(find.text('Nouvel employé'), findsNothing);
  });
}
```

`test/features/employee/widget/employee_detail_view_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/widgets/employee_detail_view.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  final overrides = [fakeSession(), employeeRepositoryProvider.overrideWithValue(FakeEmployeeRepository())];

  testWidgets('shows the employee fields', (tester) async {
    await pumpAtWidth(tester, 380, const Scaffold(body: EmployeeDetailView(id: 'emp3')), overrides: overrides);
    expect(find.text('EMP0000003'), findsOneWidget);
    expect(find.text('0102030405'), findsOneWidget);
    expect(find.text('usr3'), findsOneWidget);
  });

  testWidgets('an unknown employee shows "Employé introuvable." with a retry', (tester) async {
    await pumpAtWidth(tester, 380, const Scaffold(body: EmployeeDetailView(id: 'emp999')), overrides: overrides);
    expect(find.text('Employé introuvable.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('the panel closes', (tester) async {
    var closed = false;
    await pumpAtWidth(
      tester,
      380,
      Scaffold(body: EmployeeDetailPanel(id: 'emp3', onClose: () => closed = true)),
      overrides: overrides,
    );
    await tester.tap(find.byTooltip('Fermer'));
    expect(closed, isTrue);
  });
}
```

- [ ] **Step 2 : vérifier l'échec** — `flutter test test/core/widget test/features/employee/widget` → ÉCHEC.

- [ ] **Step 3 : implémenter les widgets communs**

`lib/core/widgets/state_views.dart`

```dart
import 'package:flutter/material.dart';

import '../theme.dart';

/// Liste vide (avec ou sans filtres).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ]),
        ),
      );
}

/// Chargement en échec, avec un bouton pour réessayer.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
          ]),
        ),
      );
}
```

`lib/core/widgets/pagination_bar.dart`

```dart
import 'package:flutter/material.dart';

/// « 21–40 sur 134 » avec page précédente / suivante. Un callback null désactive le bouton.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.offset,
    required this.count,
    required this.total,
    this.onPrevious,
    this.onNext,
  });

  final int offset;
  final int count;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(
            child: Text(
              count == 0 ? '0 sur $total' : '${offset + 1}–${offset + count} sur $total',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Page précédente', icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
          IconButton(tooltip: 'Page suivante', icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ]),
      );
}
```

`lib/core/widgets/search_field.dart`

```dart
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
```

- [ ] **Step 4 : implémenter les widgets Employés**

`lib/features/employee/widgets/employee_badges.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/role.dart';
import '../../../core/theme.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});
  final Role role;

  @override
  Widget build(BuildContext context) => _Pill(label: role.label, color: Theme.of(context).colorScheme.primary);
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) =>
      _Pill(label: isActive ? 'Actif' : 'Inactif', color: isActive ? AppColors.green : AppColors.red);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}
```

`lib/features/employee/widgets/employee_card.dart`

```dart
import 'package:flutter/material.dart';

import '../employee_model.dart';
import 'employee_badges.dart';

/// Ligne de liste pour les petits écrans (web compact et mobile).
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({super.key, required this.employee, required this.onTap});
  final Employee employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
          title: Text(employee.employeeNumber, overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              RoleBadge(role: employee.role),
              StatusPill(isActive: employee.isActive),
              if (employee.phone case final phone?) Text(phone),
            ]),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}
```

`lib/features/employee/widgets/employee_table.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../employee_model.dart';
import 'employee_badges.dart';

/// Tableau pour les écrans moyens et grands. Défile horizontalement si la place manque.
class EmployeeTable extends StatelessWidget {
  const EmployeeTable({
    super.key,
    required this.employees,
    required this.onTap,
    this.showCreatedAt = true,
    this.selectedId,
  });

  final List<Employee> employees;
  final ValueChanged<Employee> onTap;
  final bool showCreatedAt;
  final String? selectedId;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columns: [
                  const DataColumn(label: Text('Matricule')),
                  const DataColumn(label: Text('Rôle')),
                  const DataColumn(label: Text('Téléphone')),
                  const DataColumn(label: Text('Statut')),
                  if (showCreatedAt) const DataColumn(label: Text('Créé le')),
                ],
                rows: [
                  for (final e in employees)
                    DataRow(
                      key: ValueKey(e.id),
                      selected: e.id == selectedId,
                      onSelectChanged: (_) => onTap(e),
                      cells: [
                        DataCell(Text(e.employeeNumber)),
                        DataCell(RoleBadge(role: e.role)),
                        DataCell(Text(e.phone ?? '—')),
                        DataCell(StatusPill(isActive: e.isActive)),
                        if (showCreatedAt) DataCell(Text(formatDate(e.createdAt))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
```

`lib/features/employee/widgets/employee_filter_fields.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/role.dart';

class RoleFilterField extends StatelessWidget {
  const RoleFilterField({super.key, required this.value, required this.onChanged, this.width});
  final Role? value;
  final ValueChanged<Role?> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: DropdownButtonFormField<Role?>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Rôle', isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous les rôles')),
            for (final r in Role.values) DropdownMenuItem(value: r, child: Text(r.label)),
          ],
          onChanged: onChanged,
        ),
      );
}

class StatusFilterField extends StatelessWidget {
  const StatusFilterField({super.key, required this.value, required this.onChanged, this.width});
  final bool? value;
  final ValueChanged<bool?> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: DropdownButtonFormField<bool?>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Statut', isDense: true),
          items: const [
            DropdownMenuItem(value: null, child: Text('Tous les statuts')),
            DropdownMenuItem(value: true, child: Text('Actifs')),
            DropdownMenuItem(value: false, child: Text('Inactifs')),
          ],
          onChanged: onChanged,
        ),
      );
}
```

`lib/features/employee/widgets/employee_toolbar.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/widgets/search_field.dart';
import '../employee_model.dart';
import 'employee_filter_fields.dart';

/// Recherche, filtres et création. Passe à la ligne quand la place manque ;
/// en [compact], les champs prennent toute la largeur et le bouton devient une icône.
class EmployeeToolbar extends StatelessWidget {
  const EmployeeToolbar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.onCreate,
    this.compact = false,
  });

  final EmployeeFilters filters;
  final ValueChanged<EmployeeFilters> onChanged;
  final VoidCallback onCreate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fieldWidth = compact ? double.infinity : 200.0;
    return Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SizedBox(
        width: compact ? double.infinity : 280,
        child: SearchField(
          label: 'Matricule',
          initialValue: filters.search,
          onChanged: (v) => onChanged(EmployeeFilters(search: v, role: filters.role, isActive: filters.isActive)),
        ),
      ),
      RoleFilterField(
        width: fieldWidth,
        value: filters.role,
        onChanged: (r) => onChanged(EmployeeFilters(search: filters.search, role: r, isActive: filters.isActive)),
      ),
      StatusFilterField(
        width: fieldWidth,
        value: filters.isActive,
        onChanged: (a) => onChanged(EmployeeFilters(search: filters.search, role: filters.role, isActive: a)),
      ),
      if (compact)
        IconButton.filled(tooltip: 'Nouvel employé', icon: const Icon(Icons.add), onPressed: onCreate)
      else
        FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Nouvel employé')),
    ]);
  }
}
```

`lib/features/employee/widgets/employee_detail_view.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/widgets/state_views.dart';
import '../employee_controller.dart';
import '../employee_model.dart';
import 'employee_badges.dart';

/// Contenu de la fiche, partagé par le panneau (grand écran) et la page (petit écran).
class EmployeeDetailView extends ConsumerWidget {
  const EmployeeDetailView({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(employeeDetailProvider(id))) {
        AsyncData(:final value) => _Details(employee: value),
        AsyncError(:final error) =>
          ErrorState(message: employeeErrorMessage(error), onRetry: () => ref.invalidate(employeeDetailProvider(id))),
        _ => const Center(child: CircularProgressIndicator()),
      };
}

class _Details extends StatelessWidget {
  const _Details({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Text(employee.employeeNumber,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          RoleBadge(role: employee.role),
          StatusPill(isActive: employee.isActive),
        ]),
        const Divider(height: 32),
        _Field(label: 'Téléphone', value: employee.phone ?? '—'),
        _Field(label: 'Créé le', value: formatDate(employee.createdAt)),
        _Field(label: 'Modifié le', value: formatDate(employee.updatedAt)),
        _Field(label: 'Identifiant utilisateur', value: employee.userId),
      ]);
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: text.labelMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 2),
        SelectableText(value, style: text.bodyLarge),
      ]),
    );
  }
}

/// Fiche affichée à droite de la liste sur grand écran.
class EmployeeDetailPanel extends StatelessWidget {
  const EmployeeDetailPanel({super.key, required this.id, required this.onClose});
  final String id;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          ListTile(
            title: Text("Détail de l'employé", style: Theme.of(context).textTheme.titleMedium),
            trailing: IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: onClose),
          ),
          const Divider(height: 1),
          Expanded(child: EmployeeDetailView(key: ValueKey(id), id: id)),
        ]),
      );
}
```

- [ ] **Step 5 : vérifier** — `flutter test` → PASSE ; `flutter analyze` → aucun problème.

- [ ] **Step 6 : commit**

```bash
git add lib/core/widgets lib/features/employee/widgets test/core/widget test/features/employee/widget
git commit -m "feat(employee): add shared state views and employee display widgets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10 : formulaire de création, page détail, page/dialogue de création

**Files :**
- Create: `lib/features/employee/widgets/employee_form.dart`
- Create: `lib/features/employee/screens/employee_detail_page.dart`, `lib/features/employee/screens/employee_create_page.dart`
- Test: `test/features/employee/widget/employee_form_test.dart`

**Interfaces :**
- Consumes : `employeeFormControllerProvider`, `allUsersProvider`, `allDirectoriesProvider`, `directorySitesProvider`, `EmployeeDraft`.
- Produces : `EmployeeForm({required ValueChanged<Employee> onCreated, String? title})` ; `EmployeeDetailPage({required String id})` ; `EmployeeCreatePage()` ; `Future<void> openEmployeeCreate(BuildContext context, {required bool asDialog})`.

- [ ] **Step 1 : écrire les tests qui échouent** — `test/features/employee/widget/employee_form_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/widgets/employee_form.dart';
import 'package:pointage/features/user/user_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  late FakeEmployeeRepository repo;
  late Employee? created;

  List<Override> overrides({FakeUserRepository? users}) => [
        fakeSession(),
        employeeRepositoryProvider.overrideWithValue(repo),
        userRepositoryProvider.overrideWithValue(users ?? FakeUserRepository()),
        directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository()),
      ];

  Future<void> pumpForm(WidgetTester tester, {FakeUserRepository? users}) => pumpAtWidth(
        tester,
        800,
        Scaffold(body: EmployeeForm(onCreated: (e) => created = e)),
        height: 1400,
        overrides: overrides(users: users),
      );

  Future<void> choose(WidgetTester tester, String fieldLabel, String option) async {
    await tester.tap(find.widgetWithText(InputDecorator, fieldLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Créer'));
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = FakeEmployeeRepository();
    created = null;
  });

  testWidgets('required fields and lengths are checked before sending', (tester) async {
    await pumpForm(tester);
    await submit(tester);
    expect(find.text('Champ obligatoire'), findsNWidgets(3)); // utilisateur, annuaire, matricule
    await tester.enterText(find.widgetWithText(TextFormField, 'Matricule'), 'EMP1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Téléphone (facultatif)'), '123');
    await submit(tester);
    expect(find.text('Entre 10 et 20 caractères'), findsNWidgets(2));
    expect(repo.lastDraft, isNull);
  });

  testWidgets('the site list waits for a directory', (tester) async {
    await pumpForm(tester);
    expect(find.text("Choisissez d'abord un annuaire"), findsOneWidget);
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    expect(find.text("Choisissez d'abord un annuaire"), findsNothing);
    expect(find.text('Site principal'), findsOneWidget);
  });

  testWidgets('a valid form sends the draft and reports the new employee', (tester) async {
    await pumpForm(tester);
    await choose(tester, 'Utilisateur', 'Ana Dossou — ana@pointage.bj');
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    await choose(tester, 'Site (facultatif)', 'Siège Cotonou');
    await tester.enterText(find.widgetWithText(TextFormField, 'Matricule'), ' EMP0000099 ');
    await submit(tester);
    expect(repo.lastDraft?.userId, 'usr1');
    expect(repo.lastDraft?.directoryId, 'dir1');
    expect(repo.lastDraft?.siteId, 'sit1');
    expect(repo.lastDraft?.employeeNumber, 'EMP0000099');
    expect(repo.lastDraft?.phone, isNull);
    expect(created?.employeeNumber, 'EMP0000099');
  });

  testWidgets('a backend refusal stays in the form', (tester) async {
    repo.createError = ApiException('Ce matricule est déjà utilisé.', status: 409);
    await pumpForm(tester);
    await choose(tester, 'Utilisateur', 'Ana Dossou — ana@pointage.bj');
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    await tester.enterText(find.widgetWithText(TextFormField, 'Matricule'), 'EMP0000099');
    await submit(tester);
    expect(find.text('Ce matricule est déjà utilisé.'), findsOneWidget);
    expect(created, isNull);
  });

  testWidgets('options that failed to load can be retried and block the submit', (tester) async {
    await pumpForm(tester, users: FakeUserRepository(error: ApiException('Erreur serveur (500)', status: 500)));
    expect(find.text('Chargement impossible'), findsOneWidget);
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    await tester.enterText(find.widgetWithText(TextFormField, 'Matricule'), 'EMP0000099');
    await submit(tester);
    expect(tester.takeException(), isNull);
    expect(repo.lastDraft, isNull);
    expect(find.text('Choisissez un utilisateur.'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : vérifier l'échec** — `flutter test test/features/employee/widget/employee_form_test.dart` → ÉCHEC.

- [ ] **Step 3 : implémenter le formulaire** — `lib/features/employee/widgets/employee_form.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/role.dart';
import '../../../core/theme.dart';
import '../../directory/directory_controller.dart';
import '../../user/user_controller.dart';
import '../employee_controller.dart';
import '../employee_model.dart';

/// Formulaire de création. Les règles reprennent celles du backend (`CreateEmployeeRequest`).
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
  final _number = TextEditingController();
  final _phone = TextEditingController();
  String? _userId;
  String? _directoryId;
  String? _siteId;
  Role _role = Role.employee;
  bool _isActive = false;
  DateTime? _startDate;

  /// Erreur locale : une liste de choix n'a pas pu se charger.
  String? _missing;

  @override
  void dispose() {
    _number.dispose();
    _phone.dispose();
    super.dispose();
  }

  static String? _length(String? v, {required bool required}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return required ? 'Champ obligatoire' : null;
    return s.length < 10 || s.length > 20 ? 'Entre 10 et 20 caractères' : null;
  }

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
    setState(() => _missing = _userId == null
        ? 'Choisissez un utilisateur.'
        : _directoryId == null
            ? 'Choisissez un annuaire.'
            : null);
    if (!valid || _missing != null) return;
    final phone = _phone.text.trim();
    final created = await ref.read(employeeFormControllerProvider.notifier).submit(EmployeeDraft(
          userId: _userId!,
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
          _OptionsField(
            label: 'Utilisateur',
            options: ref.watch(allUsersProvider).whenData((users) => {for (final u in users) u.id: u.displayName}),
            value: _userId,
            onRetry: () => ref.invalidate(allUsersProvider),
            onChanged: (v) => setState(() => _userId = v),
          ),
          const SizedBox(height: 16),
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
```

Note pour le test « champs obligatoires » : `findsNWidgets(3)` compte les validateurs Utilisateur, Annuaire et Matricule. Le message `_missing` (« Choisissez un utilisateur. ») s'affiche aussi sous les boutons dans ce cas ; c'est voulu et cela ne change pas le compte.

- [ ] **Step 4 : pages** — `lib/features/employee/screens/employee_detail_page.dart`

```dart
import 'package:flutter/material.dart';

import '../widgets/employee_detail_view.dart';

/// Fiche en plein écran (téléphone, tablette, et mobile).
class EmployeeDetailPage extends StatelessWidget {
  const EmployeeDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Employé')),
        body: SafeArea(child: EmployeeDetailView(id: id)),
      );
}
```

`lib/features/employee/screens/employee_create_page.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../employee_model.dart';
import '../widgets/employee_form.dart';

/// Ouvre la création : dialogue (écrans moyens et grands) ou page plein écran (téléphone).
Future<void> openEmployeeCreate(BuildContext context, {required bool asDialog}) async {
  final messenger = ScaffoldMessenger.of(context);
  final created = asDialog
      ? await showDialog<Employee>(
          context: context,
          builder: (dialogContext) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: EmployeeForm(title: 'Nouvel employé', onCreated: (e) => Navigator.of(dialogContext).pop(e)),
            ),
          ),
        )
      : await Navigator.of(context).push<Employee>(MaterialPageRoute(builder: (_) => const EmployeeCreatePage()));
  if (created != null) {
    messenger.showSnackBar(
      SnackBar(backgroundColor: AppColors.green, content: Text('Employé ${created.employeeNumber} créé')),
    );
  }
}

class EmployeeCreatePage extends StatelessWidget {
  const EmployeeCreatePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nouvel employé')),
        body: SafeArea(child: EmployeeForm(onCreated: (e) => Navigator.of(context).pop(e))),
      );
}
```

- [ ] **Step 5 : vérifier** — `flutter test` → PASSE ; `flutter analyze` → aucun problème.

- [ ] **Step 6 : commit**

```bash
git add lib/features/employee test/features/employee/widget/employee_form_test.dart
git commit -m "feat(employee): add creation form, detail page and create page/dialog

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Partie D — Frontend : écrans

### Task 11 : `EmployeeWebScreen`

**Files :**
- Create: `lib/features/employee/screens/employee_web_screen.dart`
- Test: `test/features/employee/widget/employee_web_screen_test.dart`

**Interfaces :**
- Consumes : `AdminShell`, `NavItem`, `Breakpoints`, `employeeControllerProvider`, widgets des Tasks 9–10.
- Produces : `EmployeeWebScreen()`.

Mise en page : la **navigation** dépend de la fenêtre (`Breakpoints.of`), mais le choix **tableau ou cartes** dépend de la place réellement disponible pour la liste (`LayoutBuilder` + `Breakpoints.fromWidth`). Ainsi la liste reste lisible quand le menu latéral et le panneau de détail prennent de la place : moins de 600 px → cartes, de 600 à 1023 px → tableau sans « Créé le », 1024 px et plus → tableau complet.

- [ ] **Step 1 : écrire les tests qui échouent** — `test/features/employee/widget/employee_web_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/layout/admin_shell.dart';
import 'package:pointage/core/layout/nav_item.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/screens/employee_web_screen.dart';
import 'package:pointage/features/employee/widgets/employee_card.dart';
import 'package:pointage/features/employee/widgets/employee_detail_view.dart';
import 'package:pointage/features/user/user_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  late FakeEmployeeRepository repo;
  setUp(() => repo = FakeEmployeeRepository());

  List<Override> overrides() => [
        fakeSession(),
        employeeRepositoryProvider.overrideWithValue(repo),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository()),
      ];

  // L'écran est testé dans la vraie coquille : la place disponible est celle de l'application.
  Future<void> pumpScreen(WidgetTester tester, double width, {double height = 900}) => pumpAtWidth(
        tester,
        width,
        AdminShell(menus: [NavItem(label: 'Employés', icon: Icons.badge_outlined, builder: (_) => const EmployeeWebScreen())]),
        height: height,
        overrides: overrides(),
      );

  testWidgets('360 px: cards, full-width toolbar, no overflow', (tester) async {
    await pumpScreen(tester, 360, height: 740);
    expect(find.byType(EmployeeCard), findsWidgets);
    expect(find.byType(DataTable), findsNothing);
    expect(find.byTooltip('Nouvel employé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('800 px: table without the creation date', (tester) async {
    await pumpScreen(tester, 800, height: 1000);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Créé le'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1440 px: full table', (tester) async {
    await pumpScreen(tester, 1440);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Créé le'), findsOneWidget);
    expect(find.text('Nouvel employé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination moves page by page', (tester) async {
    await pumpScreen(tester, 1440);
    expect(find.text('1–20 sur 45'), findsOneWidget);
    await tester.tap(find.byTooltip('Page suivante'));
    await tester.pumpAndSettle();
    expect(find.text('21–40 sur 45'), findsOneWidget);
    expect(find.text('EMP0000021'), findsOneWidget);
  });

  testWidgets('1440 px: a row opens the side panel, which closes', (tester) async {
    await pumpScreen(tester, 1440);
    await tester.tap(find.text('EMP0000002'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(EmployeeDetailPanel), matching: find.text('EMP0000002')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeDetailPanel), findsNothing);
  });

  testWidgets('360 px: a card opens the full-screen detail', (tester) async {
    await pumpScreen(tester, 360, height: 740);
    await tester.tap(find.text('EMP0000001'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Employé'), findsOneWidget);
  });

  testWidgets('1440 px: creation opens a dialog; 360 px: a page', (tester) async {
    await pumpScreen(tester, 1440);
    await tester.tap(find.text('Nouvel employé'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    await pumpScreen(tester, 360, height: 740);
    await tester.tap(find.byTooltip('Nouvel employé'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Nouvel employé'), findsOneWidget);
  });

  testWidgets('empty states tell "no employee" from "no result"', (tester) async {
    repo.all.clear();
    await pumpScreen(tester, 1440);
    expect(find.text('Aucun employé'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'EMP0000001');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat pour ces filtres'), findsOneWidget);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    repo.listError = ApiException('Erreur serveur (500)', status: 500);
    await pumpScreen(tester, 800, height: 1000);
    expect(find.text('Erreur serveur (500)'), findsOneWidget);
    repo.listError = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
  });
}
```

- [ ] **Step 2 : vérifier l'échec** — `flutter test test/features/employee/widget/employee_web_screen_test.dart` → ÉCHEC.

- [ ] **Step 3 : implémenter** — `lib/features/employee/screens/employee_web_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/pagination_bar.dart';
import '../../../core/widgets/state_views.dart';
import '../employee_controller.dart';
import '../employee_model.dart';
import '../widgets/employee_card.dart';
import '../widgets/employee_detail_view.dart';
import '../widgets/employee_table.dart';
import '../widgets/employee_toolbar.dart';
import 'employee_create_page.dart';
import 'employee_detail_page.dart';

/// Back-office : liste filtrable et paginée. Détail en panneau à droite sur grand écran,
/// en page plein écran sinon.
class EmployeeWebScreen extends ConsumerStatefulWidget {
  const EmployeeWebScreen({super.key});

  @override
  ConsumerState<EmployeeWebScreen> createState() => _EmployeeWebScreenState();
}

class _EmployeeWebScreenState extends ConsumerState<EmployeeWebScreen> {
  String? _selectedId;

  EmployeeController get _controller => ref.read(employeeControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    Future.microtask(_controller.refresh);
  }

  void _open(Employee employee) {
    if (Breakpoints.of(context) == WindowSize.expanded) {
      setState(() => _selectedId = employee.id);
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EmployeeDetailPage(id: employee.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(employeeControllerProvider, (prev, next) {
      // Erreur alors qu'une liste est affichée (rafraîchissement) : on la garde et on prévient.
      if (next.error != null && next.items.isNotEmpty && prev?.error != next.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(backgroundColor: AppColors.red, content: Text(next.error!)));
      }
    });
    final state = ref.watch(employeeControllerProvider);
    final window = Breakpoints.of(context);

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (window != WindowSize.compact) ...[
        // En compact, le titre est déjà dans l'AppBar de la coquille.
        Text('Employés', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
      ],
      EmployeeToolbar(
        filters: state.filters,
        compact: window == WindowSize.compact,
        onChanged: _controller.setFilters,
        onCreate: () => openEmployeeCreate(context, asDialog: window != WindowSize.compact),
      ),
      const SizedBox(height: 12),
      SizedBox(height: 2, child: state.loading && state.items.isNotEmpty ? const LinearProgressIndicator() : null),
      const SizedBox(height: 8),
      Expanded(child: _body(state)),
      if (state.items.isNotEmpty)
        PaginationBar(
          offset: state.offset,
          count: state.items.length,
          total: state.total,
          onPrevious: state.page > 0 && !state.loading ? () => _controller.goToPage(state.page - 1) : null,
          onNext: state.hasMore && !state.loading ? () => _controller.goToPage(state.page + 1) : null,
        ),
    ]);

    final selected = _selectedId;
    if (window != WindowSize.expanded || selected == null) return list;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: list),
      const SizedBox(width: 24),
      SizedBox(
        width: 380,
        child: EmployeeDetailPanel(id: selected, onClose: () => setState(() => _selectedId = null)),
      ),
    ]);
  }

  Widget _body(EmployeeState state) {
    if (state.loading && state.items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(message: state.error!, onRetry: _controller.refresh);
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: Icons.badge_outlined,
        message: state.filters.isEmpty ? 'Aucun employé' : 'Aucun résultat pour ces filtres',
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final size = Breakpoints.fromWidth(constraints.maxWidth);
      if (size == WindowSize.compact) {
        return ListView.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => EmployeeCard(employee: state.items[i], onTap: () => _open(state.items[i])),
        );
      }
      return EmployeeTable(
        employees: state.items,
        showCreatedAt: size == WindowSize.expanded,
        selectedId: _selectedId,
        onTap: _open,
      );
    });
  }
}
```

- [ ] **Step 4 : vérifier** — `flutter test` → PASSE ; `flutter analyze` → aucun problème.

- [ ] **Step 5 : commit**

```bash
git add lib/features/employee/screens/employee_web_screen.dart test/features/employee/widget/employee_web_screen_test.dart
git commit -m "feat(employee): add responsive web employee screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12 : `EmployeeMobileScreen`

**Files :**
- Create: `lib/features/employee/screens/employee_mobile_screen.dart`
- Test: `test/features/employee/widget/employee_mobile_screen_test.dart`

**Interfaces :**
- Produces : `EmployeeMobileScreen()`.

- [ ] **Step 1 : écrire les tests qui échouent** — `test/features/employee/widget/employee_mobile_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/screens/employee_mobile_screen.dart';
import 'package:pointage/features/employee/widgets/employee_card.dart';
import 'package:pointage/features/user/user_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  late FakeEmployeeRepository repo;

  List<Override> overrides() => [
        fakeSession(),
        employeeRepositoryProvider.overrideWithValue(repo),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository()),
      ];

  Future<void> pumpScreen(WidgetTester tester, {double height = 800}) =>
      pumpAtWidth(tester, 390, const EmployeeMobileScreen(), height: height, overrides: overrides());

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('scrolling to the bottom loads the next page', (tester) async {
    repo = FakeEmployeeRepository([for (var n = 1; n <= 30; n++) fakeEmployee(n)]);
    await pumpScreen(tester);
    expect(repo.calls, hasLength(1));
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(repo.calls.last.offset, 20);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('EMP0000030'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a list shorter than the screen still loads the rest', (tester) async {
    repo = FakeEmployeeRepository();
    await pumpScreen(tester, height: 3000);
    await frames(tester);
    expect(repo.calls.length, greaterThanOrEqualTo(2));
  });

  testWidgets('a failure while loading more does not retry in a loop', (tester) async {
    repo = FakeEmployeeRepository();
    await pumpScreen(tester);
    repo.listError = ApiException('Erreur serveur (500)', status: 500);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await frames(tester);
    expect(repo.calls, hasLength(2));
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads the list', (tester) async {
    repo = FakeEmployeeRepository();
    await pumpScreen(tester);
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.calls, hasLength(2));
    expect(repo.calls.last.offset, 0);
  });

  testWidgets('filters live in a bottom sheet', (tester) async {
    repo = FakeEmployeeRepository();
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Filtres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tous les rôles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manager').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last.filters.role, Role.manager);
    expect(repo.calls.last.offset, 0);
  });

  testWidgets('an empty result can still be pulled to refresh', (tester) async {
    repo = FakeEmployeeRepository([]);
    await pumpScreen(tester);
    expect(find.text('Aucun employé'), findsOneWidget);
    await tester.fling(find.text('Aucun employé'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.calls, hasLength(2));
  });

  testWidgets('a card opens the detail, the + button opens the creation page', (tester) async {
    repo = FakeEmployeeRepository();
    await pumpScreen(tester);
    await tester.tap(find.byType(EmployeeCard).first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Employé'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nouvel employé'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Nouvel employé'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : vérifier l'échec** — `flutter test test/features/employee/widget/employee_mobile_screen_test.dart` → ÉCHEC.

- [ ] **Step 3 : implémenter** — `lib/features/employee/screens/employee_mobile_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_views.dart';
import '../employee_controller.dart';
import '../employee_model.dart';
import '../widgets/employee_card.dart';
import '../widgets/employee_filter_fields.dart';
import 'employee_create_page.dart';
import 'employee_detail_page.dart';

/// App mobile : recherche, filtres en feuille du bas, liste à défilement infini.
class EmployeeMobileScreen extends ConsumerStatefulWidget {
  const EmployeeMobileScreen({super.key});

  @override
  ConsumerState<EmployeeMobileScreen> createState() => _EmployeeMobileScreenState();
}

class _EmployeeMobileScreenState extends ConsumerState<EmployeeMobileScreen> {
  final _scroll = ScrollController();

  EmployeeController get _controller => ref.read(employeeControllerProvider.notifier);
  EmployeeFilters get _filters => ref.read(employeeControllerProvider).filters;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    Future.microtask(_controller.refresh);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Près du bas de la liste, ou liste trop courte pour défiler : on charge la suite.
  /// Pas après une erreur, sinon on relancerait en boucle (« Réessayer » est proposé).
  void _maybeLoadMore() {
    if (!mounted || !_scroll.hasClients || ref.read(employeeControllerProvider).error != null) return;
    if (_scroll.position.extentAfter < 300) _controller.loadMore();
  }

  void _openFilters() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Filtres', style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 16),
              RoleFilterField(
                value: _filters.role,
                onChanged: (r) =>
                    _controller.setFilters(EmployeeFilters(search: _filters.search, role: r, isActive: _filters.isActive)),
              ),
              const SizedBox(height: 16),
              StatusFilterField(
                value: _filters.isActive,
                onChanged: (a) =>
                    _controller.setFilters(EmployeeFilters(search: _filters.search, role: _filters.role, isActive: a)),
              ),
            ]),
          ),
        ),
      );

  void _openDetail(Employee employee) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EmployeeDetailPage(id: employee.id)));

  @override
  Widget build(BuildContext context) {
    ref.listen(employeeControllerProvider, (prev, next) {
      if (next.error != null && next.items.isNotEmpty && prev?.error != next.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(backgroundColor: AppColors.red, content: Text(next.error!)));
      }
    });
    final state = ref.watch(employeeControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employés'),
        actions: [
          IconButton(
            tooltip: 'Filtres',
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: state.filters.role != null || state.filters.isActive != null,
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouvel employé',
        onPressed: () => openEmployeeCreate(context, asDialog: false),
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchField(
            label: 'Matricule',
            initialValue: state.filters.search,
            onChanged: (v) =>
                _controller.setFilters(EmployeeFilters(search: v, role: _filters.role, isActive: _filters.isActive)),
          ),
        ),
        Expanded(child: RefreshIndicator(onRefresh: _controller.refresh, child: _list(state))),
      ]),
    );
  }

  Widget _list(EmployeeState state) {
    if (state.loading && state.items.isEmpty) return const Center(child: CircularProgressIndicator());
    final placeholder = state.error != null && state.items.isEmpty
        ? ErrorState(message: state.error!, onRetry: _controller.refresh)
        : state.items.isEmpty
            ? EmptyState(
                icon: Icons.badge_outlined,
                message: state.filters.isEmpty ? 'Aucun employé' : 'Aucun résultat pour ces filtres',
              )
            : null;
    if (placeholder != null) {
      // Défilable, pour que « tirer pour rafraîchir » marche aussi sur une liste vide.
      return LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: constraints.maxHeight, child: placeholder)],
        ),
      );
    }
    final footer = state.hasMore || state.loadingMore;
    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88), // place pour le bouton flottant
      itemCount: state.items.length + (footer ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i < state.items.length) {
          return EmployeeCard(employee: state.items[i], onTap: () => _openDetail(state.items[i]));
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: state.error != null && !state.loadingMore
                ? TextButton.icon(
                    onPressed: _controller.loadMore, icon: const Icon(Icons.refresh), label: const Text('Réessayer'))
                : const CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4 : vérifier** — `flutter test` → PASSE ; `flutter analyze` → aucun problème.

- [ ] **Step 5 : commit**

```bash
git add lib/features/employee/screens/employee_mobile_screen.dart test/features/employee/widget/employee_mobile_screen_test.dart
git commit -m "feat(employee): add mobile employee screen with infinite scroll

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Partie E — Branchement et vérification

### Task 13 : points d'entrée, déplacement du pointage

**Files :**
- Move: `lib/features/punch/punch_screen.dart` → `lib/features/punch/screens/punch_mobile_screen.dart` (classe `PunchScreen` → `PunchMobileScreen`)
- Modify: `lib/main.dart`, `lib/main_admin.dart`

**Interfaces :**
- Consumes : `MobileShell`, `AdminShell`, `NavItem`, `LoginScreen`, `sessionProvider`, `EmployeeWebScreen`, `EmployeeMobileScreen`, `PunchMobileScreen`.

- [ ] **Step 1 : déplacer le pointage**

```bash
mkdir -p lib/features/punch/screens
git mv lib/features/punch/punch_screen.dart lib/features/punch/screens/punch_mobile_screen.dart
```

Dans le fichier déplacé : renommer `PunchScreen` en `PunchMobileScreen` (déclaration et constructeur) et corriger les imports relatifs :

```dart
import '../../../core/theme.dart';
import '../../auth/session_provider.dart';
import '../punch_controller.dart';
import '../punch_repository.dart';
```

Aucun autre changement : le comportement du pointage ne bouge pas.

- [ ] **Step 2 : `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/layout/mobile_shell.dart';
import 'core/layout/nav_item.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_provider.dart';
import 'features/employee/screens/employee_mobile_screen.dart';
import 'features/punch/screens/punch_mobile_screen.dart';

void main() => runApp(const ProviderScope(child: PointageApp()));

/// Onglets de l'app mobile. L'onglet Employés est ouvert à tous pour l'instant (pas de contrôle par rôle).
final _tabs = [
  NavItem(label: 'Pointage', icon: Icons.fingerprint, builder: (_) => const PunchMobileScreen()),
  NavItem(label: 'Employés', icon: Icons.badge_outlined, builder: (_) => const EmployeeMobileScreen()),
];

class PointageApp extends ConsumerWidget {
  const PointageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return MaterialApp(
      title: 'Pointage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: switch (session) {
        AsyncData(value: null) => const LoginScreen(),
        AsyncData() => MobileShell(tabs: _tabs),
        // build() ne lève jamais : seul le chargement initial arrive ici.
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}
```

- [ ] **Step 3 : `lib/main_admin.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/layout/admin_shell.dart';
import 'core/layout/nav_item.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_provider.dart';
import 'features/employee/screens/employee_web_screen.dart';

/// Back-office web : `flutter run -d chrome -t lib/main_admin.dart`
void main() => runApp(const ProviderScope(child: AdminApp()));

/// Menus du back-office. Ajouter un menu = ajouter une entrée ici (son écran
/// `screens/<module>_web_screen.dart` doit être responsive, voir AdminShell).
final adminMenus = [
  NavItem(label: 'Employés', icon: Icons.badge_outlined, builder: (_) => const EmployeeWebScreen()),
];

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return MaterialApp(
      title: 'Pointage — Administration',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: switch (session) {
        AsyncData(value: null) => const LoginScreen(),
        AsyncData() => AdminShell(menus: adminMenus),
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}
```

- [ ] **Step 4 : vérifier** — `flutter analyze` → aucun problème ; `flutter test` → tout PASSE. Contrôler qu'il ne reste plus de référence : `grep -rn "PunchScreen\b\|punch_screen.dart\|employee_screen.dart" lib test` → aucun résultat.

Les deux `main` utilisent `AppTheme` (Google Fonts, téléchargement réseau) : ils ne sont pas testés en widget test. La vérification se fait en manuel (Task 14).

- [ ] **Step 5 : commit**

```bash
git add lib
git commit -m "feat: wire employee screens into the admin and mobile shells

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14 : vérification complète et test manuel

**Files :** aucun (sauf corrections trouvées, qui reprennent le cycle test → code → commit dans la tâche concernée).

- [ ] **Step 1 : suites complètes**

```bash
cd /var/www/workspace/Pointage/backend && uv run pytest -q
cd /var/www/workspace/Pointage/frontend && flutter analyze && flutter test
```

Attendu : backend → seul `test_punch_on_a_deactivated_site_is_refused` échoue (préexistant) ; frontend → 0 problème, tous les tests passent.

- [ ] **Step 2 : lancer le backend avec le CORS du back-office**

Le backend refuse les origines non listées (`cors_origins = []` par défaut et `.env` n'en déclare pas). Sans modifier `.env`, lancer le backend comme d'habitude en ajoutant la variable d'environnement `CORS_ORIGINS='["http://localhost:5000"]'` (pydantic-settings donne la priorité aux variables d'environnement sur `.env`).

- [ ] **Step 3 : back-office dans Chrome**

```bash
cd /var/www/workspace/Pointage/frontend
flutter run -d chrome -t lib/main_admin.dart --web-port 5000 --dart-define=API_URL=http://localhost:8000
```

Se connecter, puis redimensionner la fenêtre (ou utiliser les outils de développement, mode appareil) à **360, 800, 1024, 1440 et 1920 px** et vérifier à chaque taille :
- navigation : tiroir, rail ou menu latéral selon la taille ; aucune bande jaune et noire de débordement ;
- liste : cartes ou tableau, avec ou sans « Créé le » ;
- pagination, recherche par matricule exact, filtres de rôle et de statut ;
- détail : panneau à 1440 px, page en dessous de 1024 px ;
- création : dialogue ou page, avec un matricule déjà pris (le message doit rester dans le formulaire), puis une création réussie (snackbar verte, liste rafraîchie) ;
- déconnexion.

- [ ] **Step 4 : app mobile**

```bash
adb reverse tcp:8000 tcp:8000
flutter run -t lib/main.dart --dart-define=API_URL=http://localhost:8000
```

Vérifier : onglet Pointage inchangé ; onglet Employés avec défilement infini, tirer pour rafraîchir, filtres, détail, création.

- [ ] **Step 5 : rendre compte** — lister ce qui a été vérifié à la main et ce qui ne l'a pas été (par exemple pas d'appareil Android disponible), sans rien présenter comme vérifié qui ne l'a pas été.

---

## Limites connues (hors périmètre, à signaler)

- La recherche est un **matricule exact** : le filtre backend `employee_number` compare l'égalité. Une recherche partielle demande un filtre `contains` côté backend.
- Les listes de choix du formulaire chargent les **100 premiers** utilisateurs et annuaires.
- Pas de `flutter_localizations` : le sélecteur de date et les textes intégrés de Flutter (« Open navigation menu », etc.) restent en anglais.
- Aucun contrôle par rôle (voulu pour les tests) ; `PATCH /employees/{id}` n'est pas implémenté côté backend.
