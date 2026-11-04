import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_expenses/app/app.dart';
import 'package:pocket_expenses/features/accounts/domain/account_movement.dart';
import 'package:pocket_expenses/features/accounts/domain/account_repository.dart';
import 'package:pocket_expenses/features/accounts/domain/money_account.dart';
import 'package:pocket_expenses/features/accounts/presentation/account_controller.dart';
import 'package:pocket_expenses/features/accounts/presentation/accounts_page.dart';
import 'package:pocket_expenses/features/expenses/domain/expense.dart';
import 'package:pocket_expenses/features/expenses/domain/expense_repository.dart';
import 'package:pocket_expenses/features/expenses/presentation/expense_controller.dart';

class FakeExpenseRepository implements ExpenseRepository {
  final List<Expense> _expenses = [];

  @override
  Future<List<Expense>> getAll() async => _expenses;

  @override
  Future<int> add(Expense expense) async {
    final id = _expenses.length + 1;
    _expenses.add(expense.copyWith(id: id));
    return id;
  }

  @override
  Future<({int imported, int duplicates})> addImported(
          List<Expense> expenses) async =>
      (imported: 0, duplicates: 0);

  @override
  Future<void> update(Expense expense) async {}

  @override
  Future<void> delete(int id) async {}
}

class FakeAccountRepository implements AccountRepository {
  bool blockRemoval = false;
  int deleteCalls = 0;
  @override
  Future<List<MoneyAccount>> getAccounts() async => const [
        MoneyAccount(id: 1, name: 'Cash on Hand', balance: 0),
        MoneyAccount(id: 2, name: 'GCash', balance: 0),
        MoneyAccount(id: 3, name: 'Savings Account', balance: 0),
      ];

  @override
  Future<List<AccountMovement>> getMovements() async => const [];

  @override
  Future<int> addAccount(String name) async => 4;

  @override
  Future<String?> accountRemovalBlocker(int accountId) async =>
      blockRemoval ? 'This account has expense history.' : null;

  @override
  Future<void> deleteAccount(int accountId) async {
    deleteCalls++;
  }

  @override
  Future<void> adjustBalance(
      {required int accountId,
      required double change,
      required DateTime date,
      String? note}) async {}

  @override
  Future<void> transfer(
      {required int fromAccountId,
      required int toAccountId,
      required double amount,
      required DateTime date,
      String? note}) async {}
}

void main() {
  testWidgets('App renders correctly smoke test', (WidgetTester tester) async {
    final repository = FakeExpenseRepository();
    final controller = ExpenseController(repository);
    final accountController = AccountController(FakeAccountRepository());

    await tester.pumpWidget(ExpenseApp(
        controller: controller, accountController: accountController));
    await tester.pumpAndSettle();

    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
  });

  testWidgets('Accounts page shows account actions without overflowing',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AccountController(FakeAccountRepository());
    await controller.load();
    await tester
        .pumpWidget(MaterialApp(home: AccountsPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('Balances'), findsOneWidget);
    expect(find.byTooltip('Account options'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Recent money movements'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Undo latest'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked account removal does not delete the account',
      (WidgetTester tester) async {
    final repository = FakeAccountRepository()..blockRemoval = true;
    final controller = AccountController(repository);
    await controller.load();
    await tester
        .pumpWidget(MaterialApp(home: AccountsPage(controller: controller)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Account options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove account').last);
    await tester.pumpAndSettle();

    expect(find.text('Account not removed'), findsOneWidget);
    expect(repository.deleteCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
