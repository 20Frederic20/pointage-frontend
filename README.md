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
    auth/              # connexion : code par email ou mot de passe, session 36 h (stockage sécurisé)
    punch/             # pointage : repository (GPS + POST /time-entries), controller, écran
```

Dépendance à ajouter une fois : `flutter pub add flutter_secure_storage`
(jetons de session ; le refresh token ne doit pas finir en clair sur le téléphone).

En dev, les codes de connexion arrivent dans Mailpit : http://localhost:8045

Config déjà faite : permissions Internet + GPS (Android, iOS), HTTP en clair autorisé
uniquement en debug Android, titre/manifest web.
