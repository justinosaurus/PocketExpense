import 'package:flutter/foundation.dart';

import '../domain/account_movement.dart';
import '../domain/account_repository.dart';
import '../domain/money_account.dart';

class AccountController extends ChangeNotifier {
  AccountController(this._repository);
  final AccountRepository _repository;

  List<MoneyAccount> _accounts = [];
  List<AccountMovement> _movements = [];
  bool _loading = true;
  String? _error;

  List<MoneyAccount> get accounts => List.unmodifiable(_accounts);
  List<AccountMovement> get movements => List.unmodifiable(_movements);
  bool get isLoading => _loading;
  String? get error => _error;
  double get totalBalance =>
      _accounts.fold(0, (sum, account) => sum + account.balance);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _accounts = await _repository.getAccounts();
      _movements = await _repository.getMovements();
    } catch (_) {
      _error = 'Could not load account balances. Please try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshBalances() async {
    try {
      _accounts = await _repository.getAccounts();
      notifyListeners();
    } catch (_) {
      _error = 'Could not refresh account balances.';
      notifyListeners();
    }
  }

  Future<void> addAccount(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError('Enter an account name.');
    if (_accounts.any(
        (account) => account.name.toLowerCase() == cleaned.toLowerCase())) {
      throw ArgumentError('An account with this name already exists.');
    }
    await _repository.addAccount(cleaned);
    await load();
  }

  Future<void> deleteAccount(int accountId) async {
    await _repository.deleteAccount(accountId);
    await load();
  }

  Future<String?> accountRemovalBlocker(int accountId) =>
      _repository.accountRemovalBlocker(accountId);

  Future<void> adjust(
      {required int accountId,
      required double change,
      required DateTime date,
      String? note}) async {
    await _repository.adjustBalance(
        accountId: accountId, change: change, date: date, note: note);
    await load();
  }

  Future<void> transfer(
      {required int fromAccountId,
      required int toAccountId,
      required double amount,
      required DateTime date,
      String? note}) async {
    await _repository.transfer(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        date: date,
        note: note);
    await load();
  }
}
