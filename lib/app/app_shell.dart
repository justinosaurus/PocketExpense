import 'dart:async';

import 'package:flutter/material.dart';

import '../features/accounts/presentation/account_controller.dart';
import '../features/accounts/presentation/accounts_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/expenses/presentation/expense_controller.dart';
import '../features/expenses/presentation/expense_form_page.dart';
import '../features/expenses/presentation/expense_history_page.dart';

class AppShell extends StatefulWidget {
  const AppShell(
      {super.key, required this.controller, required this.accountController});
  final ExpenseController controller;
  final AccountController accountController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
          controller: widget.controller,
          accountController: widget.accountController),
      ExpenseHistoryPage(
          controller: widget.controller,
          accountController: widget.accountController),
      AccountsPage(controller: widget.accountController),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
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
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Accounts'),
        ],
      ),
    );
  }
}
