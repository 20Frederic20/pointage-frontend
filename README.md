# Pointage — frontend Flutter

Un seul projet, deux applications qui partagent `lib/core` (thème, client API) :

| App | Plateformes | Lancer |
|---|---|---|
| Pointage (employés) | Android, iOS | `flutter run -t lib/main.dart` |
| Administration | Web | `flutter run -d chrome -t lib/main_admin.dart` |

URL de l'API : `--dart-define=API_URL=http://<ip-du-pc>:8000`
(par défaut `localhost:8000` sur le web, `10.0.2.2:8000` depuis l'émulateur Android).

```
lib/
  main.dart            # entrée mobile
  main_admin.dart      # entrée web admin
  core/                # partagé : thème Vert/Jaune/Rouge, client HTTP
  features/
    auth/              # connexion mobile (matricule)
    punch/             # pointage : repository (GPS + POST /time-entries), controller, écran
```

Config déjà faite : permissions Internet + GPS (Android, iOS), HTTP en clair autorisé
uniquement en debug Android, titre/manifest web.
