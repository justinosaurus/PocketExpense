import 'package:flutter/material.dart';

import '../features/expenses/presentation/expense_controller.dart';
import '../features/accounts/presentation/account_controller.dart';
import 'app_shell.dart';
import 'theme.dart';

class ExpenseApp extends StatelessWidget {
  const ExpenseApp(
      {super.key, required this.controller, required this.accountController});

  final ExpenseController controller;
  final AccountController accountController;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Pocket Expenses',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: AppShell(
            controller: controller, accountController: accountController),
      );
}
