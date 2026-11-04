import 'account_movement.dart';
import 'money_account.dart';

abstract interface class AccountRepository {
  Future<List<MoneyAccount>> getAccounts();
  Future<List<AccountMovement>> getMovements();
  Future<int> addAccount(String name);
  Future<String?> accountRemovalBlocker(int accountId);
  Future<void> deleteAccount(int accountId);
  Future<void> adjustBalance(
      {required int accountId,
      required double change,
      required DateTime date,
      String? note});
  Future<void> transfer(
      {required int fromAccountId,
      required int toAccountId,
      required double amount,
      required DateTime date,
      String? note});
}
