import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../features/ai/providers/ai_controller.dart';
import '../features/auth/providers/auth_controller.dart';
import '../features/auth/screens/auth_gate.dart';
import '../features/budget/providers/budget_controller.dart';
import '../features/expenses/providers/expense_controller.dart';
import '../features/expenses/providers/legacy_claim_controller.dart';
import '../features/profile/providers/profile_controller.dart';
import '../features/settings/providers/theme_controller.dart';
import '../features/shell/app_shell.dart';
import 'app_dependencies.dart';

class MonneeApp extends StatelessWidget {
  const MonneeApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDependencies>.value(value: dependencies),
        ChangeNotifierProvider<AuthController>(
          create: (_) =>
              AuthController(dependencies.accounts)..restoreSession(),
        ),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(dependencies.settings)..load(),
        ),
        ChangeNotifierProxyProvider<AuthController, ExpenseController>(
          create: (_) => ExpenseController(
            dependencies.expenses,
            dependencies.receiptStorage,
          ),
          update: (_, auth, controller) =>
              controller!..bindUser(auth.user?.id),
        ),
        ChangeNotifierProxyProvider<AuthController, BudgetController>(
          create: (_) => BudgetController(dependencies.budgets),
          update: (_, auth, controller) =>
              controller!..bindUser(auth.user?.id),
        ),
        ChangeNotifierProxyProvider<AuthController, AiController>(
          create: (_) => AiController(dependencies.analyzer),
          update: (_, auth, controller) =>
              controller!..bindUser(auth.user?.id),
        ),
        ChangeNotifierProvider<LegacyClaimController>(
          create: (_) => LegacyClaimController(dependencies.expenses),
        ),
        ChangeNotifierProvider<ProfileController>(
          create: (context) => ProfileController(
            context.read<AuthController>(),
            dependencies.avatarStorage,
          ),
        ),
      ],
      child: const _MonneeMaterialApp(),
    );
  }
}

class _MonneeMaterialApp extends StatelessWidget {
  const _MonneeMaterialApp();

  @override
  Widget build(BuildContext context) {
    final mode = context.select<ThemeController, ThemeMode>(
      (controller) => controller.mode,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '$kAppName - Quản lý chi tiêu',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AuthGate(
        authenticatedBuilder: (context) {
          final userId = context.read<AuthController>().user?.id;

          return AppShell(key: ValueKey<int?>(userId));
        },
      ),
    );
  }
}