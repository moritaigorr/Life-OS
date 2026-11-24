import 'package:flutter/foundation.dart';

import 'auth_repository.dart';

enum AuthFormMode { signIn, signUp, recoverPassword, setNewPassword }

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;
  bool isLoading = false;
  String? message;
  bool messageIsError = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> submit({
    required AuthFormMode mode,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (mode != AuthFormMode.setNewPassword &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(cleanEmail)) {
      _setMessage('Digite um e-mail válido.', error: true);
      return;
    }
    if (mode == AuthFormMode.setNewPassword && password.length < 8) {
      _setMessage('Use uma senha com pelo menos 8 caracteres.', error: true);
      return;
    }
    if ((mode == AuthFormMode.signIn || mode == AuthFormMode.signUp) &&
        password.isEmpty) {
      _setMessage('Digite sua senha.', error: true);
      return;
    }

    isLoading = true;
    message = null;
    notifyListeners();
    try {
      switch (mode) {
        case AuthFormMode.signIn:
          await _repository.signIn(cleanEmail, password);
          break;
        case AuthFormMode.signUp:
          final hasSession = await _repository.signUp(cleanEmail, password);
          if (!hasSession) {
            _setMessage('Confira seu e-mail para confirmar o cadastro.');
          }
          break;
        case AuthFormMode.recoverPassword:
          await _repository.sendPasswordReset(cleanEmail);
          _setMessage(
            'Se houver uma conta com esse e-mail, você receberá um link.',
          );
          break;
        case AuthFormMode.setNewPassword:
          await _repository.updatePassword(password);
          _setMessage('Senha atualizada.');
          break;
      }
    } catch (_) {
      _setMessage(_friendlyError(mode), error: true);
    } finally {
      isLoading = false;
      _notifyListeners();
    }
  }

  void clearMessage() {
    message = null;
    messageIsError = false;
    _notifyListeners();
  }

  void _setMessage(String value, {bool error = false}) {
    message = value;
    messageIsError = error;
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  String _friendlyError(AuthFormMode mode) => switch (mode) {
    AuthFormMode.signIn =>
      'Não foi possível entrar. Confira os dados e tente novamente.',
    AuthFormMode.signUp => 'Não foi possível criar a conta. Tente novamente.',
    AuthFormMode.recoverPassword =>
      'Não foi possível enviar o link. Tente novamente.',
    AuthFormMode.setNewPassword =>
      'Não foi possível atualizar a senha. Tente novamente.',
  };
}
