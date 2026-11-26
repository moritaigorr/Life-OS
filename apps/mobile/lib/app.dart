import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_client_config.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/life/life_screen.dart';
import 'features/life/supabase_life_repository.dart';
import 'features/life/life_direction_screen.dart';
import 'features/life/supabase_life_direction_repository.dart';
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
          : _AuthenticatedShell(
              client: configuredClient,
              onSignOut: repository.signOut,
            ),
    );
  }
}

class _AuthenticatedShell extends StatefulWidget {
  const _AuthenticatedShell({required this.client, required this.onSignOut});

  final SupabaseClient client;
  final VoidCallback onSignOut;

  @override
  State<_AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<_AuthenticatedShell> {
  int _selectedIndex = 0;
  bool _lifeVisited = false;
  bool _directionVisited = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selectedIndex,
      children: [
        TodayScreen(
          repository: SupabaseTaskRepository(widget.client),
          onSignOut: widget.onSignOut,
        ),
        if (_lifeVisited)
          LifeScreen(
            repository: SupabaseLifeRepository(widget.client),
            onSignOut: widget.onSignOut,
          )
        else
          const SizedBox.shrink(),
        if (_directionVisited)
          LifeDirectionScreen(
            repository: SupabaseLifeDirectionRepository(widget.client),
            onSignOut: widget.onSignOut,
          )
        else
          const SizedBox.shrink(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() {
        _selectedIndex = index;
        if (index == 1) _lifeVisited = true;
        if (index == 2) _directionVisited = true;
      }),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.today_outlined),
          selectedIcon: Icon(Icons.today_rounded),
          label: 'Hoje',
        ),
        NavigationDestination(
          icon: Icon(Icons.bubble_chart_outlined),
          selectedIcon: Icon(Icons.bubble_chart_rounded),
          label: 'Vida',
        ),
        NavigationDestination(
          icon: Icon(Icons.flag_outlined),
          selectedIcon: Icon(Icons.flag_rounded),
          label: 'Direção',
        ),
      ],
    ),
  );
}

class _TodayPlaceholder extends StatelessWidget {
  const _TodayPlaceholder();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(child: Center(child: Text('Hoje'))),
  );
}
