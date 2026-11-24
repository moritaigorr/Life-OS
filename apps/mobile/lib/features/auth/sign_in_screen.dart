import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import 'auth_controller.dart';
import 'auth_repository.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.repository,
    this.initialMode = AuthFormMode.signIn,
    super.key,
  });

  final AuthRepository? repository;
  final AuthFormMode initialMode;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late AuthFormMode _mode;
  late final AuthController? _controller;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _controller = widget.repository == null
        ? null
        : AuthController(widget.repository!);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String get _title => switch (_mode) {
    AuthFormMode.signIn => 'Entrar',
    AuthFormMode.signUp => 'Criar conta',
    AuthFormMode.recoverPassword => 'Recuperar acesso',
    AuthFormMode.setNewPassword => 'Nova senha',
  };

  String get _subtitle => switch (_mode) {
    AuthFormMode.signIn => 'Acesse sua conta para continuar.',
    AuthFormMode.signUp => 'Crie sua conta para começar.',
    AuthFormMode.recoverPassword => 'Enviaremos um link para seu e-mail.',
    AuthFormMode.setNewPassword => 'Escolha uma senha nova para sua conta.',
  };

  String get _actionLabel => switch (_mode) {
    AuthFormMode.signIn => 'Entrar',
    AuthFormMode.signUp => 'Criar conta',
    AuthFormMode.recoverPassword => 'Enviar link',
    AuthFormMode.setNewPassword => 'Salvar nova senha',
  };

  bool get _asksForPassword => _mode != AuthFormMode.recoverPassword;

  void _setMode(AuthFormMode mode) {
    setState(() {
      _mode = mode;
      _passwordController.clear();
    });
    _controller?.clearMessage();
  }

  Future<void> _submit() async {
    if (_controller == null || !_formKey.currentState!.validate()) return;
    await _controller.submit(
      mode: _mode,
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.violet,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      semanticLabel: 'Life OS',
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(_title, style: textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    _subtitle,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (widget.repository == null)
                    const _ConfigurationNotice()
                  else ...[
                    AnimatedBuilder(
                      animation: _controller!,
                      builder: (context, _) => _AuthForm(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        passwordFocus: _passwordFocus,
                        mode: _mode,
                        controller: _controller,
                        asksForPassword: _asksForPassword,
                        actionLabel: _actionLabel,
                        onSubmit: _submit,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _modeLinks(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeLinks() => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      if (_mode == AuthFormMode.signIn) ...[
        TextButton(
          onPressed: () => _setMode(AuthFormMode.signUp),
          child: const Text('Criar conta'),
        ),
        TextButton(
          onPressed: () => _setMode(AuthFormMode.recoverPassword),
          child: const Text('Esqueci minha senha'),
        ),
      ] else if (_mode == AuthFormMode.signUp ||
          _mode == AuthFormMode.recoverPassword) ...[
        TextButton(
          onPressed: () => _setMode(AuthFormMode.signIn),
          child: const Text('Voltar para entrar'),
        ),
        if (_mode == AuthFormMode.signUp)
          TextButton(
            onPressed: () => _setMode(AuthFormMode.recoverPassword),
            child: const Text('Recuperar senha'),
          ),
      ],
    ],
  );
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordFocus,
    required this.mode,
    required this.controller,
    required this.asksForPassword,
    required this.actionLabel,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode passwordFocus;
  final AuthFormMode mode;
  final AuthController controller;
  final bool asksForPassword;
  final String actionLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode != AuthFormMode.setNewPassword) ...[
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: asksForPassword
                  ? TextInputAction.next
                  : TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                    ? null
                    : 'Digite um e-mail válido.';
              },
              onFieldSubmitted: asksForPassword
                  ? (_) => passwordFocus.requestFocus()
                  : (_) => onSubmit(),
            ),
            if (asksForPassword) const SizedBox(height: 16),
          ],
          if (asksForPassword)
            TextFormField(
              controller: passwordController,
              focusNode: passwordFocus,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: mode == AuthFormMode.signIn
                  ? const [AutofillHints.password]
                  : const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: mode == AuthFormMode.setNewPassword
                    ? 'Nova senha'
                    : 'Senha',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) {
                final password = value ?? '';
                if (mode == AuthFormMode.signIn && password.isEmpty) {
                  return 'Digite sua senha.';
                }
                if ((mode == AuthFormMode.signUp ||
                        mode == AuthFormMode.setNewPassword) &&
                    password.length < 8) {
                  return 'Use pelo menos 8 caracteres.';
                }
                return null;
              },
              onFieldSubmitted: (_) => onSubmit(),
            ),
          if (controller.message case final message?) ...[
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: TextStyle(
                  color: controller.messageIsError
                      ? Theme.of(context).colorScheme.error
                      : AppColors.mutedInk,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: controller.isLoading ? null : onSubmit,
            child: controller.isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ConfigurationNotice extends StatelessWidget {
  const _ConfigurationNotice();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      'Configure o Supabase local para habilitar sua conta. Veja env/example.json e o README do app.',
    ),
  );
}
