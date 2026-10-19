import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/validators/auth_validator.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/widgets/auth_error_banner.dart';
import '../../auth/widgets/password_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await auth.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
      confirmPassword: _confirmController.text,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    setState(() => _saving = false);

    messenger.showSnackBar(
      const SnackBar(content: Text('Đã đổi mật khẩu thành công.')),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) AuthErrorBanner(message: error),
                    PasswordField(
                      controller: _currentController,
                      label: 'Mật khẩu hiện tại',
                      enabled: !_saving,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.password],
                      validator: (value) => (value ?? '').isEmpty
                          ? 'Vui lòng nhập mật khẩu hiện tại.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _newController,
                      label: 'Mật khẩu mới (tối thiểu $kMinPasswordLength ký tự)',
                      enabled: !_saving,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: validatePassword,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _confirmController,
                      label: 'Xác nhận mật khẩu mới',
                      enabled: !_saving,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: (value) => validateConfirmPassword(
                        _newController.text,
                        value,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Đổi mật khẩu'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}