import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/data/app_database.dart';
import 'features/accounts/data/sqlite_account_repository.dart';
import 'features/accounts/presentation/account_controller.dart';
import 'features/expenses/data/sqlite_expense_repository.dart';
import 'features/expenses/presentation/expense_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final expenseController =
      ExpenseController(SqliteExpenseRepository(database));
  final accountController =
      AccountController(SqliteAccountRepository(database));
  runApp(ExpenseApp(
      controller: expenseController,
      accountController: accountController,
      database: database));
}
