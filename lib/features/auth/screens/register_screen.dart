import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/validators/auth_validator.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onGoToLogin});

  final VoidCallback onGoToLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>();

    if (auth.busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    await auth.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final error = auth.errorMessage;

    return AuthScaffold(
      title: 'Tạo tài khoản',
      subtitle: 'Mỗi tài khoản có dữ liệu chi tiêu riêng trên thiết bị này.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) AuthErrorBanner(message: error),
              TextFormField(
                controller: _nameController,
                enabled: !auth.busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Họ tên',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: validateName,
              ),
              const SizedBox(height: 16),
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
                label: 'Mật khẩu (tối thiểu $kMinPasswordLength ký tự)',
                enabled: !auth.busy,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: validatePassword,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirmController,
                label: 'Xác nhận mật khẩu',
                enabled: !auth.busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (value) => validateConfirmPassword(
                  _passwordController.text,
                  value,
                ),
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
                    : const Text('Đăng ký'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: auth.busy ? null : widget.onGoToLogin,
                child: const Text('Đã có tài khoản? Đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}