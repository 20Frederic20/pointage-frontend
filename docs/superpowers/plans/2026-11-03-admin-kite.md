# Back-office sur la base Kite — plan

Source : [ColorlibHQ/kite-flutter-admin-dashboard](https://github.com/ColorlibHQ/kite-flutter-admin-dashboard) (licence MIT, conservée dans `packages/kite_ui/LICENSE`).

## Décisions de l'utilisateur
- Le back-office **repart du template Kite**, mais **dans `frontend/`** : même projet que l'app mobile, avec le code commun partagé (connexion, client API, modèles).
- **Thème blanc uniquement** : thème clair ardoise, sans bouton de mode sombre ni choix d'accent.
- Repris de Kite : la **coquille** (barre latérale à rubriques, barre du haut), un **tableau de bord d'accueil** avec nos chiffres, et la **recherche Ctrl+K**.
- **Pas repris** : traductions multiples (le français seulement), mode sombre, Supabase, données factices, et les écrans d'exemple (boutique, kanban, boîte de réception, discussion, calendrier, assistant, formulaires de démo).
- Flutter passe à 3.47 ou plus (mise à jour faite sur la machine).
- On travaille sur `main`, sans branche.

## Étapes
1. **Socle.**
   - Copier `packages/kite_ui` (composants, jetons de couleur, graphiques, tableau de données) et l'ajouter en dépendance locale, avec `go_router`.
   - Monter le SDK à la version minimale de Kite.
   - Vérifier que l'app mobile compile et que tous les tests passent.
2. **Coquille du back-office**, dans `lib/admin/` :
   - `ShadApp.router` avec le thème clair ardoise et la police Inter ;
   - les routes `/` (tableau de bord), `/employes`, `/anomalies`, `/pointages` et `/annuaires` (ADMIN), avec redirection vers la connexion quand la session est absente ;
   - une barre latérale à rubriques (VUE D'ENSEMBLE, GESTION, ADMINISTRATION), la tuile utilisateur (identifiant · entreprise) et la déconnexion ;
   - une barre du haut avec le titre et le bouton de recherche ;
   - une navigation adaptée au mobile pour les petits écrans.
   
   Dans un premier temps, les écrans existants s'affichent tels quels dans la nouvelle coquille.
3. **Tableau de bord**, pour aujourd'hui :
   - présents, absents, retards et anomalies en attente, tirés de `/work-time` et de `/anomalies` ;
   - les dernières anomalies ouvertes ;
   - les retards du jour.
4. **Recherche Ctrl+K** : les écrans du back-office, les employés par matricule, les anomalies ouvertes.
5. **Restylage des écrans** (Employés, Anomalies, Pointages, Annuaires) avec les composants `kite_ui` : en-tête de page, cartes, boutons, badges et tableaux. La logique et les fournisseurs Riverpod existants sont conservés, et les tests sont adaptés.
6. **Nettoyage.**
   - Retirer l'ancienne `AdminShell`.
   - Vérifier l'affichage à 360, 800 et 1440 px.
   - Relancer `flutter analyze` et `flutter test`, puis faire un essai dans Chrome.
