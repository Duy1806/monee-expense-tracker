import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  bool _showRegister = false;

  void _toggle() {
    context.read<AuthController>().clearError();
    setState(() => _showRegister = !_showRegister);
  }

  @override
  Widget build(BuildContext context) {
    if (_showRegister) {
      return RegisterScreen(
        key: const ValueKey('register'),
        onGoToLogin: _toggle,
      );
    }

    return LoginScreen(
      key: const ValueKey('login'),
      onGoToRegister: _toggle,
    );
  }
}