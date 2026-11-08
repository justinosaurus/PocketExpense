import 'dart:async';

import 'package:flutter/material.dart';

import '../features/analytics/presentation/analytics_page.dart';
import '../features/accounts/presentation/account_action_page.dart';
import '../features/accounts/presentation/account_controller.dart';
import '../features/accounts/presentation/accounts_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/expenses/presentation/expense_controller.dart';
import '../features/expenses/presentation/expense_form_page.dart';
import '../features/expenses/presentation/expense_history_page.dart';

class AppShell extends StatefulWidget {
  const AppShell(
      {super.key,
      required this.controller,
      required this.accountController,
      required this.themeMode,
      required this.onThemeModeChanged});
  final ExpenseController controller;
  final AccountController accountController;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  AnalyticsFocus _analyticsFocus = AnalyticsFocus.expenses;
  bool _listeningToExpenses = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    await widget.accountController.load();
    if (!mounted) return;
    widget.controller.addListener(_refreshBalances);
    _listeningToExpenses = true;
    await widget.controller.load();
  }

  void _refreshBalances() =>
      unawaited(widget.accountController.refreshBalances());

  @override
  void dispose() {
    if (_listeningToExpenses) {
      widget.controller.removeListener(_refreshBalances);
    }
    super.dispose();
  }

  Future<void> _addExpense() async {
    if (widget.accountController.accounts.isEmpty) {
      await widget.accountController.load();
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final saved = await navigator.push<bool>(MaterialPageRoute(
      builder: (_) => ExpenseFormPage(
          controller: widget.controller,
          accountController: widget.accountController),
    ));
    if (saved == true && mounted) setState(() => _index = 1);
  }

  Future<void> _addIncome() async {
    if (widget.accountController.accounts.isEmpty) {
      await widget.accountController.load();
    }
    if (!mounted) return;
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AccountActionPage(
          controller: widget.accountController,
          action: AccountActionType.income),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
          controller: widget.controller,
          accountController: widget.accountController,
          onOpenAnalytics: (focus) => setState(() {
                _analyticsFocus = focus;
                _index = 2;
              })),
      ExpenseHistoryPage(
          controller: widget.controller,
          accountController: widget.accountController),
      AnalyticsPage(
        controller: widget.controller,
        accountController: widget.accountController,
        focus: _analyticsFocus,
        onAddExpense: _addExpense,
      ),
      AccountsPage(controller: widget.accountController),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 2 ? 'Analytics insights' : 'Pocket Expenses'),
        actions: [
          PopupMenuButton<ThemeMode>(
            tooltip: 'Choose appearance',
            initialValue: widget.themeMode,
            onSelected: widget.onThemeModeChanged,
            icon: const Icon(Icons.brightness_6_outlined),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ThemeMode.system,
                child: ListTile(
                  leading: Icon(Icons.settings_brightness),
                  title: Text('System default'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: ThemeMode.light,
                child: ListTile(
                  leading: Icon(Icons.light_mode_outlined),
                  title: Text('Light'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: ThemeMode.dark,
                child: ListTile(
                  leading: Icon(Icons.dark_mode_outlined),
                  title: Text('Dark'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add-income',
            onPressed: _addIncome,
            icon: const Icon(Icons.trending_up),
            label: const Text('Add income'),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'add-expense',
            onPressed: _addExpense,
            icon: const Icon(Icons.add),
            label: const Text('Add expense'),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Overview'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Analytics'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Accounts'),
        ],
      ),
    );
  }
}
