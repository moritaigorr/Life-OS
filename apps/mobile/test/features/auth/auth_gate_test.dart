import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/auth/auth_repository.dart';
import 'package:life_os/features/auth/auth_gate.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.currentSession});

  final _changes = StreamController<AuthSnapshot>.broadcast();

  @override
  AuthSession? currentSession;

  @override
  Stream<AuthSnapshot> get authStateChanges => _changes.stream;

  void emit(AuthSnapshot snapshot) => _changes.add(snapshot);

  @override
  Future<void> signIn(String email, String password) async {
    currentSession = const AuthSession('user-a');
    emit(const AuthSnapshot(session: AuthSession('user-a')));
  }

  @override
  Future<bool> signUp(String email, String password) async => true;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> signOut() async => _changes.add(const AuthSnapshot());

  Future<void> dispose() => _changes.close();
}

void main() {
  testWidgets('a restored session opens the authenticated route', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      currentSession: const AuthSession('user-a'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          repository: repository,
          authenticatedBuilder: (_) => const Text('Hoje'),
        ),
      ),
    );

    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Entrar'), findsNothing);
    await repository.dispose();
  });

  testWidgets('signed-out state shows the sign-in route', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          repository: repository,
          authenticatedBuilder: (_) => const Text('Hoje'),
        ),
      ),
    );

    expect(find.text('Acesse sua conta para continuar.'), findsOneWidget);
    expect(find.text('Hoje'), findsNothing);
    await repository.dispose();
  });

  testWidgets('sign-out removes the authenticated route immediately', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      currentSession: const AuthSession('user-a'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          repository: repository,
          authenticatedBuilder: (_) => const Text('Hoje'),
        ),
      ),
    );
    repository.emit(const AuthSnapshot());
    await tester.pump();

    expect(find.text('Acesse sua conta para continuar.'), findsOneWidget);
    expect(find.text('Hoje'), findsNothing);
    await repository.dispose();
  });

  testWidgets('successful sign-in moves to the authenticated route', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          repository: repository,
          authenticatedBuilder: (_) => const Text('Hoje'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password-123');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Hoje'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await repository.dispose();
  });

  testWidgets('password recovery shows the new password screen', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      currentSession: const AuthSession('user-a'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          repository: repository,
          authenticatedBuilder: (_) => const Text('Hoje'),
        ),
      ),
    );
    repository.emit(
      const AuthSnapshot(
        session: AuthSession('user-a'),
        requiresPasswordUpdate: true,
      ),
    );
    await tester.pump();

    expect(find.text('Salvar nova senha'), findsOneWidget);
    expect(find.text('Hoje'), findsNothing);
    await repository.dispose();
  });
}
