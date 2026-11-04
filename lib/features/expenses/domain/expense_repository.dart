import 'expense.dart';

abstract interface class ExpenseRepository {
  Future<List<Expense>> getAll();
  Future<int> add(Expense expense);
  Future<({int imported, int duplicates})> addImported(List<Expense> expenses);
  Future<void> update(Expense expense);
  Future<void> delete(int id);
}
