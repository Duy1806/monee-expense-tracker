import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/widgets/brand_header.dart';
import '../ai/screens/ai_analysis_screen.dart';
import '../auth/providers/auth_controller.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../expenses/add_expense_actions.dart';
import '../expenses/screens/expense_list_screen.dart';
import '../expenses/widgets/legacy_claim_dialog.dart';
import '../profile/screens/profile_screen.dart';
import '../settings/screens/settings_screen.dart';

class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const List<_Destination> _destinations = [
  _Destination(
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    label: 'Tổng quan',
  ),
  _Destination(
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    label: 'Giao dịch',
  ),
  _Destination(
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome_rounded,
    label: 'AI',
  ),
  _Destination(
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: 'Hồ sơ',
  ),
];

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const double _wideBreakpoint = 840;

  int _index = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final user = context.read<AuthController>().user;

      if (user != null) {
        showLegacyClaimDialogIfNeeded(context, userId: user.id);
      }
    });
  }

  void _select(int index) {
    if (index == _index) return;

    setState(() => _index = index);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _index,
      children: [
        DashboardScreen(onSeeAllTransactions: () => _select(1)),
        const ExpenseListScreen(),
        const AiAnalysisScreen(),
        ProfileScreen(onOpenSettings: _openSettings),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    final appBar = AppBar(
      title: _index == 0
          ? const BrandHeader(size: 32)
          : Text(_destinations[_index].label),
      actions: [
        IconButton(
          tooltip: 'Cài đặt',
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );

    final fab = _index <= 1
        ? FloatingActionButton.extended(
            onPressed: () => showAddExpenseOptions(context),
            tooltip: 'Thêm giao dịch',
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm'),
          )
        : null;

    if (wide) {
      return Scaffold(
        appBar: appBar,
        floatingActionButton: fab,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      floatingActionButton: fab,
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}