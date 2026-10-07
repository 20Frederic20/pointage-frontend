# Pointage — frontend Flutter

Un seul projet, deux applications qui partagent `lib/core` (thème, client API) :

| App | Plateformes | Lancer |
|---|---|---|
| Pointage (employés) | Android, iOS | `flutter run -t lib/main.dart` |
| Administration | Web | `flutter run -d chrome -t lib/main_admin.dart` |

URL de l'API : `--dart-define=API_URL=http://<ip-du-pc>:8000`
(par défaut `localhost:8000`).

Téléphone branché en USB (ou émulateur) : à refaire à chaque rebranchement du câble
```bash
adb reverse tcp:8000 tcp:8000
```
Sans câble, en Wi-Fi : `--dart-define=API_URL=http://<ip-du-pc>:8000`.

```
lib/
  main.dart            # entrée mobile
  main_admin.dart      # entrée web admin
  core/                # partagé : thème Vert/Jaune/Rouge, client HTTP
  features/
    auth/              # connexion par matricule OU email : code reçu par email ou mot de passe, session 36 h
    punch/             # pointage : repository (GPS + POST /time-entries), controller, écran
```

Dépendance à ajouter une fois : `flutter pub add flutter_secure_storage`
(jetons de session ; le refresh token ne doit pas finir en clair sur le téléphone).

En dev, les codes de connexion arrivent dans Mailpit : http://localhost:8045

Config déjà faite : permissions Internet + GPS (Android, iOS), HTTP en clair autorisé
uniquement en debug Android, titre/manifest web.
