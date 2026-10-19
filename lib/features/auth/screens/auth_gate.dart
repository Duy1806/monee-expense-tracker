import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import 'auth_flow_screen.dart';
import 'splash_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authenticatedBuilder});

  /// Màn hình chính hiển thị sau khi đăng nhập.
  final WidgetBuilder authenticatedBuilder;

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthController, AuthStatus>(
      (controller) => controller.status,
    );

    return switch (status) {
      AuthStatus.unknown => const SplashScreen(),
      AuthStatus.unauthenticated => const AuthFlowScreen(),
      AuthStatus.authenticated => authenticatedBuilder(context),
    };
  }
}