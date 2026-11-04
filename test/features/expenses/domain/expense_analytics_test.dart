import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_expenses/features/expenses/domain/expense.dart';
import 'package:pocket_expenses/features/expenses/domain/expense_analytics.dart';
import 'package:pocket_expenses/features/expenses/domain/expense_category.dart';

void main() {
  final expenses = [
    Expense(
        id: 1,
        amount: 100,
        date: DateTime(2026, 4, 1, 23),
        category: ExpenseCategory.food),
    Expense(
        id: 2,
        amount: 50.5,
        date: DateTime(2026, 4, 30),
        category: ExpenseCategory.food),
    Expense(
        id: 3,
        amount: 200,
        date: DateTime(2026, 5, 1),
        category: ExpenseCategory.transport),
  ];

  test('totals spending and groups amounts by category', () {
    expect(ExpenseAnalytics.total(expenses), 350.5);
    expect(ExpenseAnalytics.byCategory(expenses),
        {ExpenseCategory.food: 150.5, ExpenseCategory.transport: 200});
  });

  test('filters by inclusive calendar date range and category', () {
    final result = ExpenseAnalytics.filter(expenses,
        from: DateTime(2026, 4, 1),
        to: DateTime(2026, 4, 30),
        category: ExpenseCategory.food);
    expect(result.map((expense) => expense.id), [1, 2]);
  });

  test('accepts open ended date filters', () {
    final result =
        ExpenseAnalytics.filter(expenses, from: DateTime(2026, 5, 1));
    expect(result.map((expense) => expense.id), [3]);
  });

  test(
      'treats missing amounts as zero and excludes undated rows from date filters',
      () {
    const undated = Expense(
        id: 4, amount: null, date: null, category: ExpenseCategory.food);
    expect(ExpenseAnalytics.total([...expenses, undated]), 350.5);
    expect(ExpenseAnalytics.filter([...expenses, undated]), contains(undated));
    expect(
        ExpenseAnalytics.filter([...expenses, undated],
            from: DateTime(2026, 4, 1)),
        isNot(contains(undated)));
  });
}
