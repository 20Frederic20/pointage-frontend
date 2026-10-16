# Écrans Employés (web + mobile) et coquille admin adaptative

Date : 2026-10-16 · Statut : validé en discussion, à relire

## 1. Objectif

- Deux écrans Employés : un pour le back-office web (`main_admin.dart`), un pour l'app mobile (`main.dart`).
- Le web s'adapte à toutes les tailles d'écran (téléphone, tablette, desktop), pour Employés **et tous les futurs menus**.
- Une architecture identique dans tous les modules. Toute déviation est signalée et validée avant d'être appliquée.

Fonctionnalités de la v1 : liste paginée, recherche et filtres, détail, création.

**Hors périmètre :** contrôle d'accès par rôle (l'écran est ouvert à tous les profils pour les tests, la restriction viendra ensuite), modification (`PATCH /employees/{id}` n'est pas implémenté côté backend), suppression, `go_router`, écrans Utilisateurs et Annuaires.

## 2. Architecture frontend

### 2.1 Arborescence

```
lib/
  core/
    api_client.dart          get/post → une seule gestion d'erreur (_handle), 422 géré partout
    page.dart                Page<T> { items, total } générique
    theme.dart
    layout/
      breakpoints.dart       compact < 600 ≤ medium < 1024 ≤ expanded
      admin_menu.dart        AdminMenu(label, icon, builder) + liste adminMenus
      admin_shell.dart       coquille web adaptative
      mobile_shell.dart      barre de navigation du bas (Pointage / Employés)
    widgets/                 composants communs : état vide, erreur + réessayer, pagination
  features/
    <module>/
      <module>_model.dart
      <module>_repository.dart
      <module>_controller.dart
      screens/
        <module>_web_screen.dart
        <module>_mobile_screen.dart
      widgets/               widgets propres au module, partagés entre les deux écrans
  main.dart                  LoginScreen | MobileShell
  main_admin.dart            LoginScreen | AdminShell (même logique de session que main.dart)
```

### 2.2 Règles communes à chaque module

1. Le repository fait uniquement les appels HTTP et **renvoie des modèles**, jamais des `Map`.
2. Le controller (`Notifier<XState>`) est **partagé entre le web et le mobile**. Les écrans se limitent à afficher l'état et à appeler le controller.
3. Les écrans web utilisent `Breakpoints`. Aucune largeur n'est codée en dur.
4. Couleurs : `AppColors` / `Theme`. Transparence : `withValues(alpha:)`, jamais `withOpacity`.
5. Les imports sont relatifs, comme dans le reste du projet.
6. Le jeton est obtenu par `sessionProvider.notifier.accessToken()` dans le controller, puis passé au repository.

`punch` est mis en conformité. Son écran est déplacé vers `features/punch/screens/punch_mobile_screen.dart`, sans aucun changement de comportement.

## 3. Coquille web adaptative (`AdminShell`)

| Largeur | Navigation | Contenu |
|---|---|---|
| expanded (≥ 1024) | Menu latéral fixe de 240 px avec libellés, identifiant et déconnexion en bas | Largeur maximale de 1400 px, centré |
| medium (600–1023) | `NavigationRail` avec icônes seules (tooltip) | Pleine largeur, marges de 24 px |
| compact (< 600) | `AppBar` avec bouton menu qui ouvre un `Drawer` | Pleine largeur, marges de 16 px |

- Le `FlagStripe` reste en haut, et le menu actif est mis en évidence.
- La page affichée est un index gardé dans `adminMenuIndexProvider`, sans routeur.
- **Ajouter un menu = ajouter une entrée `AdminMenu` dans `adminMenus`.**

`MobileShell` est un `NavigationBar` en bas de l'écran, avec deux onglets : Pointage et Employés.

## 4. Écrans Employés

### 4.1 Web (`EmployeeWebScreen`)

- **Barre d'outils** :
  - recherche par matricule, déclenchée 300 ms après la dernière frappe ;
  - filtre de rôle (5 rôles + « Tous ») ;
  - filtre de statut (Actif / Inactif / Tous) ;
  - bouton « Nouvel employé ».

  Les éléments passent à la ligne sur petit écran (`Wrap`), et le bouton devient une icône en compact.
- **Liste** :
  - expanded : un tableau avec les colonnes Matricule, Rôle, Téléphone, Statut et Créé le ;
  - medium : le même tableau sans la colonne « Créé le » ;
  - compact : des cartes empilées (matricule, badge de rôle, statut, téléphone).
- **Pagination** : 20 lignes par page, boutons Précédent / Suivant, indication « 21–40 sur 134 ».
- **Détail** (`GET /employees/{id}`) : panneau latéral à droite en expanded, page plein écran avec retour en medium et compact.
- **Création** : dialogue en expanded et medium, page plein écran en compact.
- **États** :
  - chargement initial : loader centré ;
  - rafraîchissement : barre de progression fine, la liste reste affichée ;
  - erreur : message avec un bouton « Réessayer » ;
  - vide : « Aucun employé », ou « Aucun résultat pour ces filtres » si un filtre est actif.

### 4.2 Mobile (`EmployeeMobileScreen`)

- Champ de recherche en haut, filtres dans une feuille en bas de l'écran (*bottom sheet*).
- Liste de cartes avec chargement au défilement (`loadMore` en approchant du bas de la liste).
- Tirer pour rafraîchir (*pull-to-refresh*).
- Détail en page plein écran, bouton flottant « + » qui ouvre la création en plein écran.

## 5. Données et état

### 5.1 Modèles

- `Employee` : `id`, `userId`, `employeeNumber`, `role` (`Role`), `isActive`, `phone?`, `createdAt?`, `updatedAt?`. `directoryId` est retiré, parce que le backend ne le renvoie pas : le lien passe par les *assignments*.
- `Role` : une enum de 5 valeurs (`EMPLOYEE`, `MANAGER`, `HR`, `PAYROLL`, `ADMIN`), avec les libellés Employé, Manager, RH, Paie, Admin.
- `Page<T>.fromJson(json, itemFromJson)`.
- `AppUser` (`features/user/`) : `id`, `email`, `firstName?`, `lastName?`, `role`, `isActive`. Le module ne contient qu'un modèle et un repository.
- `Directory` (`features/directory/`) : `id`, `name`, `code`. Le module ne contient qu'un modèle et un repository, plus `sites(directoryId)`.
- `Site` (minimal) : `id`, `name`, utilisé par le sélecteur.

### 5.2 Repositories

- `EmployeeRepository` :
  - `list(token, {search, role, isActive, limit, offset}) → Page<Employee>`, qui envoie `employee_number`, `role`, `is_active`, `limit` et `offset` en paramètres d'URL ;
  - `getById(token, id) → Employee` ;
  - `create(token, EmployeeDraft) → Employee`.
- `UserRepository.list(token, {limit, offset}) → Page<AppUser>`.
- `DirectoryRepository.list(token, {limit, offset}) → Page<Directory>` et `sites(token, directoryId) → List<Site>`.
- `ApiClient.get` accepte des paramètres d'URL (`query`).

### 5.3 Controllers

```
EmployeeState { items, total, offset, limit = 20, filters (search, role, isActive),
                loading, loadingMore, error }
EmployeeController
  setFilters(...)  → offset = 0, recharge
  goToPage(n)      → remplace items (web)
  loadMore()       → ajoute à items (mobile) ; ne fait rien si items.length == total
  refresh()
```

- `employeeDetailProvider` : `FutureProvider.autoDispose.family<Employee, String>`.
- `EmployeeFormController` :
  - il gère le statut d'envoi et l'erreur ;
  - quand l'envoi réussit, il appelle `employeeController.refresh()`.

### 5.4 Formulaire de création

| Champ | Source / validation |
|---|---|
| Utilisateur | Liste déroulante alimentée par `GET /users`, affichée sous la forme « Prénom Nom — email » (l'email seul si le nom est absent). Obligatoire |
| Annuaire | Liste déroulante alimentée par `GET /directories`. Obligatoire |
| Site | Liste déroulante alimentée par `GET /directories/{id}/sites`, active une fois l'annuaire choisi. Facultatif |
| Matricule | De 10 à 20 caractères. Obligatoire |
| Rôle | `EMPLOYEE` par défaut |
| Téléphone | De 10 à 20 caractères. Facultatif |
| Actif | Case à cocher, décochée par défaut (comme dans le backend) |
| Début d'affectation | Sélecteur de date. Facultatif, le backend utilise la date du jour si le champ est vide |

### 5.5 Erreurs

- Les messages backend inconnus sont remplacés par un message générique en français, via `_messages` dans `ApiClient`.
- Un 404 sur le détail affiche « Employé introuvable ».
- Une erreur à la création (422 ou erreur métier) s'affiche dans le formulaire, qui reste ouvert.

## 6. Backend (`/var/www/workspace/Pointage/backend`)

Je suis l'architecture existante : query → handler → enregistrement dans `UsersContainer` → route.

1. **`GET /employees/{id}`** : `GetEmployeeByIdQuery` existe déjà. J'ajoute `GetEmployeeByIdHandler`, je l'enregistre, et j'ajoute la route. Elle renvoie un 404 « Employee not found » si l'employé n'existe pas, sur le modèle de `GET /sites/{id}`.
2. **`GET /users?role&is_active&limit&offset`** : la query et le handler sont déjà enregistrés. J'ajoute la route et `UserListResponse`, qui existe déjà.
3. **`GET /directories?limit&offset`** : j'ajoute `GetDirectoriesQuery`, `GetDirectoriesHandler` et `DirectoriesPageDTO`, plus `find` et `count` dans `IDirectoryRepository` et ses implémentations (sur le modèle de `IUserRepository`). J'ajoute aussi `DirectoryListResponse`.

**Point à vérifier :** `GetUsersHandler` part de `spec = None`, puis enchaîne `spec & …`. Un test vérifiera ce comportement. Si une correction est nécessaire, je préviendrai avant de l'appliquer.

Le backend contient une modification non commitée qui ne vient pas de ce travail (`src/identity/infrastructure/importer.py`). Je n'y touche pas.

## 7. Tests et vérification

### 7.1 Ce qu'on attend d'un bon test

- Il vérifie un **comportement observable** (une réponse HTTP, un état, ce qui s'affiche), pas un détail d'implémentation. Une refactorisation ne doit pas le casser.
- **Un comportement par test.** Son nom dit ce qu'on attend, par exemple `test_get_employee_unknown_id_returns_404` ou `'loadMore stops when all items are loaded'`.
- Il suit la structure *Arrange / Act / Assert* et ne dépend de rien d'extérieur : ni de l'ordre des tests, ni de l'heure, ni du réseau, ni d'une base réelle.
- Les faux objets se placent **aux frontières seulement** (repositories, HTTP). Le reste du code tourne pour de vrai.
- Il couvre les cas limites : liste vide, dernière page, id inconnu, paramètres invalides (422), erreur réseau.
- Chaque test est écrit **avant** le code, et on le voit échouer avant de le faire passer.

### 7.2 Organisation : par module, puis par type

Les tests sont rangés **par module, puis par type** :

```
backend/tests/
  identity/
    unit/          handlers contre des faux repositories en mémoire
    api/           routes FastAPI via TestClient (container remplacé par dependency_overrides)

frontend/test/
  helpers/         pump_at_width.dart, faux repositories communs
  core/
    unit/          ApiClient (via http MockClient), Page, Breakpoints
    widget/        AdminShell, MobileShell
  features/
    employee/
      unit/        modèles, EmployeeController, EmployeeFormController
      widget/      EmployeeWebScreen, EmployeeMobileScreen, formulaire, détail
    user/unit/  directory/unit/
```

⚠️ **Déviation à valider :** les tests backend existants sont aujourd'hui tous au même niveau (`tests/test_*.py`). Ce travail **ne les déplace pas**. Seuls les nouveaux tests suivent l'arborescence ci-dessus. Les déplacer est une tâche séparée, à faire seulement si tu le demandes. Les noms des fichiers de test restent uniques, pour éviter les conflits d'import de pytest.

### 7.3 Tests backend (`uv run pytest`)

`identity/unit/` :
- `GetEmployeeByIdHandler` : il renvoie le DTO si l'id existe, `None` sinon.
- `GetUsersHandler` : sans filtre, avec filtre de rôle, avec filtre de statut, rôle et statut combinés, `total` indépendant de `limit`. Ces tests tranchent aussi le cas `spec = None`.
- `GetDirectoriesHandler` : liste vide, pagination (`limit`, `offset`), `total`.

`identity/api/` :
- `GET /employees/{id}` : 200 avec un JSON en camelCase (`employeeNumber`, `isActive`…), 404 si l'id est inconnu.
- `GET /employees` : forme `{items, total}`, transmission des filtres et de la pagination, 422 si le rôle est invalide.
- `GET /users` et `GET /directories` : forme `{items, total}`, pagination, 422 si les paramètres sont invalides.

### 7.4 Tests frontend (`flutter test`)

Seul `flutter_test` est utilisé, déjà fourni par le SDK. `package:http/testing.dart` (`MockClient`) est inclus dans `http`, qui est déjà une dépendance.

- **unit** :
  - `Employee`, `Role`, `Page`, `AppUser` et `Directory` lus depuis du JSON réel du backend ;
  - `ApiClient` : en-têtes, paramètres d'URL, traduction des codes d'erreur, 422, corps de réponse vide ;
  - `EmployeeController` : les filtres remettent l'offset à 0, `goToPage` remplace les items, `loadMore` les ajoute et s'arrête au total, pas de double chargement, état d'erreur puis `refresh` ;
  - `EmployeeFormController` : succès (avec rafraîchissement de la liste) et erreur (le formulaire reste ouvert, avec le message).
- **widget** :
  - Responsivité : un helper `pumpAtWidth(tester, width, widget)`. `AdminShell` et `EmployeeWebScreen` sont testés à **360, 800 et 1440 px**. À chaque largeur, je vérifie la bonne navigation (Drawer, Rail ou menu latéral), la bonne vue (cartes ou tableau) et **l'absence d'exception de débordement**. Chaque futur menu réutilise ce helper.
  - États affichés : chargement, erreur avec « Réessayer », les deux variantes de l'état vide, pagination.
  - Détail : panneau latéral en expanded, page plein écran en compact.
  - Formulaire : validation des champs (longueurs du matricule et du téléphone, champs obligatoires).
  - Mobile : chargement au défilement, tirer pour rafraîchir.
- `flutter analyze` doit passer sans aucun avertissement.

**Vérification manuelle** : `flutter run -d chrome -t lib/main_admin.dart` contre le backend local, en redimensionnant la fenêtre. Tout ce qui n'a pas pu être vérifié sera signalé.
