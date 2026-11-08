import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_expenses/features/accounts/domain/account_movement.dart';
import 'package:pocket_expenses/features/accounts/domain/money_account.dart';
import 'package:pocket_expenses/features/analytics/domain/analytics_data.dart';
import 'package:pocket_expenses/features/expenses/domain/expense.dart';
import 'package:pocket_expenses/features/expenses/domain/expense_category.dart';

void main() {
  final accounts = const [
    MoneyAccount(id: 1, name: 'Cash', balance: 0),
    MoneyAccount(id: 2, name: 'Savings', balance: 0),
  ];
  final expenses = [
    Expense(
        id: 1,
        amount: 100,
        date: DateTime(2026, 11, 1),
        category: ExpenseCategory.food),
    Expense(
        id: 2,
        amount: 50,
        date: DateTime(2026, 11, 8),
        category: ExpenseCategory.transport),
    Expense(
        id: 3,
        amount: 30,
        date: DateTime(2026, 11, 4),
        category: ExpenseCategory.food,
        accountId: 2),
    Expense(
        id: 4,
        amount: 600,
        date: DateTime(2026, 10, 31),
        category: ExpenseCategory.other),
    const Expense(
        id: 5, amount: null, date: null, category: ExpenseCategory.other),
    Expense(
        id: 6,
        amount: -25,
        date: DateTime(2026, 11, 2),
        category: ExpenseCategory.other),
    Expense(
        id: 7,
        amount: double.nan,
        date: DateTime(2026, 11, 2),
        category: ExpenseCategory.other),
  ];
  final movements = [
    AccountMovement(
      id: 1,
      type: 'income',
      amount: 1000,
      date: DateTime(2026, 11, 2),
      toAccountId: 1,
      toName: 'Cash',
    ),
    AccountMovement(
      id: 2,
      type: 'income',
      amount: 400,
      date: DateTime(2026, 11, 5),
      toAccountId: 2,
      toName: 'Savings',
    ),
    AccountMovement(
      id: 3,
      type: 'transfer',
      amount: 200,
      date: DateTime(2026, 11, 5),
      toAccountId: 2,
      toName: 'Savings',
    ),
    AccountMovement(
      id: 4,
      type: 'adjustment',
      amount: 500,
      date: DateTime(2026, 11, 5),
      toAccountId: 1,
      toName: 'Cash',
    ),
    AccountMovement(
      id: 5,
      type: 'income',
      amount: 50,
      date: DateTime(2026, 10, 31),
      toAccountId: 1,
      toName: 'Cash',
    ),
  ];

  test('builds calendar ranges with equal-length previous comparisons', () {
    final now = DateTime(2026, 11, 8);
    final week = AnalyticsDateRange.current(AnalyticsPeriod.week, now);
    expect(week.start, DateTime(2026, 11, 2));
    expect(week.endExclusive, DateTime(2026, 11, 9));
    expect(week.days, 7);
    expect(week.previous.start, DateTime(2026, 10, 26));
    expect(week.previous.endExclusive, week.start);

    final month = AnalyticsDateRange.current(AnalyticsPeriod.month, now);
    expect(month.start, DateTime(2026, 11, 1));
    expect(month.days, 8);
    expect(month.previous.days, month.days);

    final quarter = AnalyticsDateRange.current(AnalyticsPeriod.quarter, now);
    expect(quarter.start, DateTime(2026, 10, 1));
    expect(AnalyticsDateRange.current(AnalyticsPeriod.year, now).start,
        DateTime(2026, 1, 1));

    final custom = AnalyticsDateRange.current(
      AnalyticsPeriod.custom,
      now,
      customStart: DateTime(2026, 11, 3, 18),
      customEnd: DateTime(2026, 11, 6, 9),
    );
    expect(custom.start, DateTime(2026, 11, 3));
    expect(custom.endExclusive, DateTime(2026, 11, 7));
    expect(custom.days, 4);
    expect(custom.contains(DateTime(2026, 11, 6, 23)), isTrue);
    expect(custom.contains(DateTime(2026, 11, 7)), isFalse);
  });

  test('excludes transfers, adjustments, invalid amounts, and undated expenses',
      () {
    final range = AnalyticsDateRange.current(
        AnalyticsPeriod.custom, DateTime(2026, 11, 8),
        customStart: DateTime(2026, 11, 1), customEnd: DateTime(2026, 11, 8));
    final analytics = AnalyticsData(
      expenses: expenses,
      movements: movements,
      accounts: accounts,
      range: range,
    );

    expect(analytics.expenseTotal, 180);
    expect(analytics.incomeTotal, 1400);
    expect(analytics.netCashFlow, 1220);
    expect(analytics.savingsRate, closeTo(1220 / 1400, 0.000001));
    expect(analytics.averageDailySpending, 22.5);
    expect(analytics.spendingByCategory, {
      ExpenseCategory.food: 130,
      ExpenseCategory.transport: 50,
    });
    expect(analytics.spendingByAccount, {'Cash': 150, 'Savings': 30});
    expect(analytics.incomeByAccount, {'Cash': 1000, 'Savings': 400});
    expect(analytics.largestExpenses.map((expense) => expense.id), [1, 2, 3]);
    expect(analytics.trend, hasLength(8));
    expect(analytics.trend[1].income, 1000);
    expect(analytics.trend[1].expenses, 0);
  });

  test('account and category filters scope expenses and income correctly', () {
    final range = AnalyticsDateRange.current(
        AnalyticsPeriod.month, DateTime(2026, 11, 8));
    final analytics = AnalyticsData(
      expenses: expenses,
      movements: movements,
      accounts: accounts,
      range: range,
      accountId: 1,
      category: ExpenseCategory.food,
    );

    expect(analytics.expenseTotal, 100);
    expect(analytics.incomeTotal, 1000);
    expect(analytics.netCashFlow, 900);
    expect(analytics.spendingByCategory, {ExpenseCategory.food: 100});

    final previous = analytics.previousPeriod(
      allExpenses: [
        Expense(
          id: 8,
          amount: 50,
          date: DateTime(2026, 10, 26),
          category: ExpenseCategory.food,
        ),
      ],
      allMovements: [
        AccountMovement(
          id: 6,
          type: 'income',
          amount: 500,
          date: DateTime(2026, 10, 26),
          toAccountId: 1,
        ),
      ],
      accounts: accounts,
    );
    expect(previous.expenseTotal, 50);
    expect(previous.incomeTotal, 500);
  });

  test('returns an undefined savings rate when no income exists', () {
    final analytics = AnalyticsData(
      expenses: expenses,
      movements: const [],
      accounts: accounts,
      range: AnalyticsDateRange.current(
          AnalyticsPeriod.month, DateTime(2026, 11, 8)),
    );
    expect(analytics.savingsRate, isNull);
    expect(analytics.netCashFlow, -180);
  });
}
