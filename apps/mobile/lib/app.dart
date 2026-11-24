import 'package:material_ui/material_ui.dart';

import 'core/supabase_client_config.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/tasks/supabase_task_repository.dart';
import 'features/tasks/today_screen.dart';
import 'theme/app_theme.dart';

class LifeOsApp extends StatelessWidget {
  const LifeOsApp({this.authRepository, super.key});

  final AuthRepository? authRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _home(),
    );
  }

  Widget _home() {
    final configuredClient = SupabaseClientConfig.client;
    final repository =
        authRepository ??
        (configuredClient == null
            ? null
            : SupabaseAuthRepository(configuredClient));
    if (repository == null) return const SignInScreen(repository: null);
    return AuthGate(
      repository: repository,
      authenticatedBuilder: (_) => configuredClient == null
          ? const _TodayPlaceholder()
          : TodayScreen(
              repository: SupabaseTaskRepository(configuredClient),
              onSignOut: repository.signOut,
            ),
    );
  }
}

class _TodayPlaceholder extends StatelessWidget {
  const _TodayPlaceholder();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(child: Center(child: Text('Hoje'))),
  );
}
