import 'expense.dart';
import 'expense_category.dart';

class ExpenseAnalytics {
  static double total(Iterable<Expense> expenses) =>
      expenses.fold(0, (sum, expense) => sum + (expense.amount ?? 0));

  static Map<ExpenseCategory, double> byCategory(Iterable<Expense> expenses) {
    final totals = <ExpenseCategory, double>{};
    for (final expense in expenses) {
      final amount = expense.amount;
      if (amount == null) continue;
      totals.update(expense.category, (value) => value + amount,
          ifAbsent: () => amount);
    }
    return totals;
  }

  static List<Expense> filter(Iterable<Expense> expenses,
      {DateTime? from, DateTime? to, ExpenseCategory? category}) {
    final start =
        from == null ? null : DateTime(from.year, from.month, from.day);
    final endExclusive = to == null
        ? null
        : DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
    return expenses.where((expense) {
      final expenseDate = expense.date;
      if (expenseDate == null && (start != null || endExclusive != null)) {
        return false;
      }
      if (expenseDate == null) {
        return category == null || expense.category == category;
      }
      final date =
          DateTime(expenseDate.year, expenseDate.month, expenseDate.day);
      return (start == null || !date.isBefore(start)) &&
          (endExclusive == null || date.isBefore(endExclusive)) &&
          (category == null || expense.category == category);
    }).toList();
  }
}
