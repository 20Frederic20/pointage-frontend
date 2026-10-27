import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../auth/session_provider.dart';
import 'punch_repository.dart';

enum AssistedStep { enterNumber, confirm, selfie, sending, done, error }

class AssistedPunchState {
  const AssistedPunchState({
    this.step = AssistedStep.enterNumber,
    this.colleague,
    this.photo,
    this.contentType,
    this.entry,
    this.error,
  });

  final AssistedStep step;
  final Colleague? colleague;
  final List<int>? photo;
  final String? contentType;
  final TimeEntry? entry;
  final String? error;

  AssistedPunchState copyWith({
    AssistedStep? step,
    TimeEntry? entry,
    String? error,
  }) => AssistedPunchState(
    step: step ?? this.step,
    colleague: colleague,
    photo: photo,
    contentType: contentType,
    entry: entry ?? this.entry,
    error: error,
  );
}

/// Pointage pour un collègue ; indépendant du [PunchController] de l'utilisateur connecté.
class AssistedPunchController extends Notifier<AssistedPunchState> {
  /// Une clé par tentative : conservée si l'utilisateur réessaie le même envoi.
  String? _key;

  @override
  AssistedPunchState build() => const AssistedPunchState();

  Future<void> lookup(String employeeNumber) async {
    final number = employeeNumber.trim();
    if (number.isEmpty) return;
    try {
      final token = await ref.read(sessionProvider.notifier).accessToken();
      if (token == null) return;
      final colleague = await ref
          .read(punchRepositoryProvider)
          .lookupColleague(token, number);
      state = AssistedPunchState(
        step: AssistedStep.confirm,
        colleague: colleague,
      );
    } catch (e) {
      state = AssistedPunchState(
        step: AssistedStep.error,
        error: _lookupMessage(e),
      );
    }
  }

  /// « C'est moi » : le nom affiché est le bon, on passe au selfie.
  void confirm() {
    if (state.colleague == null) return;
    state = state.copyWith(step: AssistedStep.selfie);
  }

  void setSelfie(List<int> bytes, String contentType) {
    if (state.colleague == null) return;
    state = AssistedPunchState(
      step: AssistedStep.selfie,
      colleague: state.colleague,
      photo: bytes,
      contentType: contentType,
    );
  }

  Future<void> send() async {
    final colleague = state.colleague;
    final photo = state.photo;
    final contentType = state.contentType;
    if (colleague == null || photo == null || contentType == null) return;
    if (state.step == AssistedStep.sending || state.step == AssistedStep.done) return;
    state = state.copyWith(step: AssistedStep.sending);
    try {
      final token = await ref.read(sessionProvider.notifier).accessToken();
      if (token == null) {
        // session expirée : main.dart renvoie vers la connexion
        state = state.copyWith(step: AssistedStep.selfie);
        return;
      }
      final entry = await ref
          .read(punchRepositoryProvider)
          .punchFor(
            token,
            employeeNumber: colleague.employeeNumber,
            photo: photo,
            contentType: contentType,
            idempotencyKey: _key ??= newIdempotencyKey(),
          );
      state = state.copyWith(step: AssistedStep.done, entry: entry);
    } catch (e) {
      state = state.copyWith(step: AssistedStep.error, error: _sendMessage(e));
    }
  }

  /// Nouvelle tentative : repart de zéro avec une nouvelle clé d'idempotence.
  void reset() {
    _key = null;
    state = const AssistedPunchState();
  }
}

String _lookupMessage(Object e) => switch (e) {
  ApiException(status: 404) => 'Matricule introuvable.',
  ApiException(:final message) => message,
  _ => 'Vérification impossible, vérifiez la connexion.',
};

String _sendMessage(Object e) => switch (e) {
  ApiException(:final message) => message,
  _ => 'Pointage impossible, vérifiez la connexion.',
};

final assistedPunchControllerProvider =
    NotifierProvider<AssistedPunchController, AssistedPunchState>(
      AssistedPunchController.new,
    );

typedef SelfiePicker = Future<(List<int>, String)?> Function();

/// Selfie à la caméra frontale, jamais depuis la galerie. Surchargé dans les tests.
final selfiePickerProvider = Provider<SelfiePicker>(
  (ref) => () async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1080,
      imageQuality: 80,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final isPng = (file.mimeType ?? file.path).toLowerCase().contains('png');
    return (bytes, isPng ? 'image/png' : 'image/jpeg');
  },
);
