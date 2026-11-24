import 'package:material_ui/material_ui.dart';

import 'auth_repository.dart';
import 'auth_controller.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.repository,
    required this.authenticatedBuilder,
    super.key,
  });

  final AuthRepository repository;
  final WidgetBuilder authenticatedBuilder;

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthSnapshot>(
    stream: repository.authStateChanges,
    initialData: AuthSnapshot(session: repository.currentSession),
    builder: (context, snapshot) {
      final auth = snapshot.data;
      if (auth == null || snapshot.hasError || auth.session == null) {
        return SignInScreen(repository: repository);
      }
      if (auth.requiresPasswordUpdate) {
        return SignInScreen(
          key: const ValueKey('password-recovery'),
          repository: repository,
          initialMode: AuthFormMode.setNewPassword,
        );
      }
      return authenticatedBuilder(context);
    },
  );
}
