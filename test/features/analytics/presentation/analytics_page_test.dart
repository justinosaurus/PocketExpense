import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_expenses/features/accounts/domain/account_movement.dart';
import 'package:pocket_expenses/features/accounts/domain/account_repository.dart';
import 'package:pocket_expenses/features/accounts/domain/money_account.dart';
import 'package:pocket_expenses/features/accounts/presentation/account_controller.dart';
import 'package:pocket_expenses/features/analytics/presentation/analytics_page.dart';
import 'package:pocket_expenses/features/expenses/domain/expense.dart';
import 'package:pocket_expenses/features/expenses/domain/expense_category.dart';
import 'package:pocket_expenses/features/expenses/domain/expense_repository.dart';
import 'package:pocket_expenses/features/expenses/presentation/expense_controller.dart';

class _ExpenseRepository implements ExpenseRepository {
  _ExpenseRepository(this.items);

  final List<Expense> items;

  @override
  Future<List<Expense>> getAll() async => items;

  @override
  Future<int> add(Expense expense) async => 1;

  @override
  Future<({int imported, int duplicates})> addImported(
          List<Expense> expenses) async =>
      (imported: 0, duplicates: 0);

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> update(Expense expense) async {}
}

class _AccountRepository implements AccountRepository {
  _AccountRepository({this.movements = const []});

  final List<AccountMovement> movements;

  @override
  Future<List<MoneyAccount>> getAccounts() async => const [
        MoneyAccount(id: 1, name: 'Cash', balance: 0),
        MoneyAccount(id: 2, name: 'Savings', balance: 0),
      ];

  @override
  Future<List<AccountMovement>> getMovements() async => movements;

  @override
  Future<int> addAccount(String name) async => 3;

  @override
  Future<String?> accountRemovalBlocker(int accountId) async => null;

  @override
  Future<void> deleteAccount(int accountId) async {}

  @override
  Future<void> adjustBalance(
      {required int accountId,
      required double change,
      required DateTime date,
      String? note}) async {}

  @override
  Future<void> recordIncome(
      {required int accountId,
      required double amount,
      required DateTime date,
      String? note}) async {}

  @override
  Future<void> syncAccountBalance(
      {required int accountId,
      required double balance,
      required DateTime date}) async {}

  @override
  Future<void> transfer(
      {required int fromAccountId,
      required int toAccountId,
      required double amount,
      required DateTime date,
      String? note}) async {}
}

void main() {
  testWidgets('empty analytics state prompts the user to add an expense',
      (tester) async {
    final expenses = ExpenseController(_ExpenseRepository([]));
    final accounts = AccountController(_AccountRepository());
    await expenses.load();
    await accounts.load();
    var addTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnalyticsPage(
          controller: expenses,
          accountController: accounts,
          onAddExpense: () => addTapped = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No activity in this range'), findsOneWidget);
    await tester.ensureVisible(find.text('Add an expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add an expense'));
    expect(addTapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analytics shows summaries and transaction details accessibly',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final expenses = ExpenseController(_ExpenseRepository([
      Expense(
        id: 1,
        amount: 25,
        date: now,
        category: ExpenseCategory.food,
      ),
    ]));
    final accounts = AccountController(_AccountRepository(
      movements: [
        AccountMovement(
          id: 1,
          type: 'income',
          amount: 100,
          date: now,
          toAccountId: 1,
          toName: 'Cash',
        ),
        AccountMovement(
          id: 2,
          type: 'transfer',
          amount: 500,
          date: now,
          toAccountId: 1,
          toName: 'Cash',
        ),
      ],
    ));
    await expenses.load();
    await accounts.load();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnalyticsPage(
          controller: expenses,
          accountController: accounts,
          onAddExpense: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('At a glance'), findsOneWidget);
    expect(find.text('Income'), findsWidgets);
    expect(find.text('No activity in this range'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Largest expenses'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Largest expenses'), findsOneWidget);
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    expect(find.text('Expense details'), findsOneWidget);
    expect(find.text('Note'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
