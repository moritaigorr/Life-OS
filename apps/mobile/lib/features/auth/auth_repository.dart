import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSession {
  const AuthSession(this.userId);

  final String userId;
}

class AuthSnapshot {
  const AuthSnapshot({this.session, this.requiresPasswordUpdate = false});

  final AuthSession? session;
  final bool requiresPasswordUpdate;
}

abstract interface class AuthRepository {
  AuthSession? get currentSession;
  Stream<AuthSnapshot> get authStateChanges;

  Future<void> signIn(String email, String password);
  Future<bool> signUp(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  AuthSession? _sessionFrom(Session? session) {
    final userId = session?.user.id;
    return userId == null ? null : AuthSession(userId);
  }

  @override
  AuthSession? get currentSession => _sessionFrom(_client.auth.currentSession);

  @override
  Stream<AuthSnapshot> get authStateChanges async* {
    yield AuthSnapshot(session: currentSession);
    await for (final state in _client.auth.onAuthStateChange) {
      yield AuthSnapshot(
        session: _sessionFrom(state.session),
        requiresPasswordUpdate: state.event == AuthChangeEvent.passwordRecovery,
      );
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    return response.session != null;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'lifeos://auth/recover',
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
