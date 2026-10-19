import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/validators/auth_validator.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onGoToRegister});

  final VoidCallback onGoToRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>();

    if (auth.busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    await auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final error = auth.errorMessage;

    return AuthScaffold(
      title: 'Đăng nhập',
      subtitle: 'Chào mừng bạn quay lại Monee.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) AuthErrorBanner(message: error),
              TextFormField(
                controller: _emailController,
                enabled: !auth.busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: validateEmail,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _passwordController,
                label: 'Mật khẩu',
                enabled: !auth.busy,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                validator: (value) => (value ?? '').isEmpty
                    ? 'Vui lòng nhập mật khẩu.'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: auth.busy ? null : _submit,
                child: auth.busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Đăng nhập'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: auth.busy ? null : widget.onGoToRegister,
                child: const Text('Chưa có tài khoản? Đăng ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}