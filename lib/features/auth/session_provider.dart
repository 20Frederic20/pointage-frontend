import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Matricule de l'employé connecté (null = déconnecté).
// ponytail: matricule en mémoire, remplacer par le JWT quand le backend aura /auth/login.
class SessionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void login(String employeeNumber) => state = employeeNumber.trim();
  void logout() => state = null;
}

final sessionProvider = NotifierProvider<SessionNotifier, String?>(SessionNotifier.new);
