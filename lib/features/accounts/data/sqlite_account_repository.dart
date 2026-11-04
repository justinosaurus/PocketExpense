import 'package:sqflite/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../domain/account_balance.dart';
import '../domain/account_movement.dart';
import '../domain/account_repository.dart';
import '../domain/money_account.dart';

class SqliteAccountRepository implements AccountRepository {
  SqliteAccountRepository(this._appDatabase);
  final AppDatabase _appDatabase;

  @override
  Future<List<MoneyAccount>> getAccounts() async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery('''
      SELECT a.id, a.name,
        COALESCE((SELECT SUM(e.amount) FROM expenses e WHERE e.account_id = a.id), 0) AS expenses,
        COALESCE((SELECT SUM(m.amount) FROM account_movements m WHERE m.to_account_id = a.id), 0) AS incoming,
        COALESCE((SELECT SUM(m.amount) FROM account_movements m WHERE m.from_account_id = a.id), 0) AS outgoing
      FROM accounts a ORDER BY a.id
    ''');
    return rows
        .map((row) => MoneyAccount(
              id: row['id'] as int,
              name: row['name'] as String,
              balance: AccountBalance.calculate(
                expenses: (row['expenses'] as num).toDouble(),
                incoming: (row['incoming'] as num).toDouble(),
                outgoing: (row['outgoing'] as num).toDouble(),
              ),
            ))
        .toList();
  }

  @override
  Future<List<AccountMovement>> getMovements() async {
    final rows = await (await _appDatabase.database).rawQuery('''
      SELECT m.id, m.type, m.amount, m.date, m.note, f.name AS from_name, t.name AS to_name
      FROM account_movements m
      LEFT JOIN accounts f ON f.id = m.from_account_id
      LEFT JOIN accounts t ON t.id = m.to_account_id
      ORDER BY m.date DESC, m.id DESC
    ''');
    return rows
        .map((row) => AccountMovement(
              id: row['id'] as int,
              type: row['type'] as String,
              amount: (row['amount'] as num).toDouble(),
              date: DateTime.parse(row['date'] as String),
              fromName: row['from_name'] as String?,
              toName: row['to_name'] as String?,
              note: row['note'] as String?,
            ))
        .toList();
  }

  @override
  Future<int> addAccount(String name) async =>
      (await _appDatabase.database).insert('accounts', {'name': name.trim()});

  @override
  Future<String?> accountRemovalBlocker(int accountId) async =>
      _accountRemovalBlocker(await _appDatabase.database, accountId);

  @override
  Future<void> deleteAccount(int accountId) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final blocker = await _accountRemovalBlocker(txn, accountId);
      if (blocker != null) throw StateError(blocker);

      final deleted =
          await txn.delete('accounts', where: 'id = ?', whereArgs: [accountId]);
      if (deleted == 0) throw StateError('This account no longer exists.');
    });
  }

  Future<String?> _accountRemovalBlocker(
      DatabaseExecutor db, int accountId) async {
    final account = await db.query('accounts',
        columns: ['id'], where: 'id = ?', whereArgs: [accountId], limit: 1);
    if (account.isEmpty) return 'This account no longer exists.';
    final expenses = await db.rawQuery(
        'SELECT 1 FROM expenses WHERE account_id = ? LIMIT 1', [accountId]);
    if (expenses.isNotEmpty) {
      return 'This account has expense history. It cannot be removed without losing that history.';
    }
    final movements = await db.rawQuery('''SELECT 1 FROM account_movements
        WHERE from_account_id = ? OR to_account_id = ? LIMIT 1''',
        [accountId, accountId]);
    if (movements.isNotEmpty) {
      return 'This account has transfer or balance history. It cannot be removed without losing that history.';
    }
    return null;
  }

  @override
  Future<void> adjustBalance(
      {required int accountId,
      required double change,
      required DateTime date,
      String? note}) async {
    if (change == 0 || !change.isFinite) {
      throw ArgumentError('Enter a non-zero balance adjustment.');
    }
    await (await _appDatabase.database).insert('account_movements', {
      'type': 'adjustment',
      'from_account_id': change < 0 ? accountId : null,
      'to_account_id': change > 0 ? accountId : null,
      'amount': change.abs(),
      'date': _dateOnly(date),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
    });
  }

  @override
  Future<void> transfer(
      {required int fromAccountId,
      required int toAccountId,
      required double amount,
      required DateTime date,
      String? note}) async {
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Choose two different accounts.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Enter an amount greater than zero.');
    }
    await (await _appDatabase.database).insert('account_movements', {
      'type': 'transfer',
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'amount': amount,
      'date': _dateOnly(date),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
    });
  }

  String _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day).toIso8601String();
}
