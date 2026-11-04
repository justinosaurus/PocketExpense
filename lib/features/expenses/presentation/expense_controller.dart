import 'package:flutter/foundation.dart';

import '../domain/expense.dart';
import '../domain/expense_repository.dart';

class ExpenseController extends ChangeNotifier {
  ExpenseController(this._repository);
  final ExpenseRepository _repository;
  List<Expense> _expenses = [];
  bool _loading = true;
  String? _error;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _expenses = await _repository.getAll();
    } catch (_) {
      _error = 'Could not load expenses. Please try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> save(Expense expense) async {
    try {
      if (expense.id == null) {
        await _repository.add(expense);
        _expenses = await _repository.getAll();
      } else {
        await _repository.update(expense);
        _expenses = _expenses
            .map((item) => item.id == expense.id ? expense : item)
            .toList();
      }
      _error = null;
      notifyListeners();
    } catch (_) {
      _error = 'Could not save this expense. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> remove(Expense expense) async {
    if (expense.id == null) return;
    try {
      await _repository.delete(expense.id!);
      _expenses = _expenses.where((item) => item.id != expense.id).toList();
      _error = null;
      notifyListeners();
    } catch (_) {
      _error = 'Could not delete this expense. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  Future<({int imported, int duplicates})> importExpenses(
      List<Expense> expenses) async {
    try {
      final result = await _repository.addImported(expenses);
      _expenses = await _repository.getAll();
      _error = null;
      notifyListeners();
      return result;
    } catch (_) {
      _error = 'Could not import the selected file. Please try again.';
      notifyListeners();
      rethrow;
    }
  }
}
