import 'dart:math';

import '../../../core/data/app_database.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';
import 'package:sqflite/sqflite.dart';

class SqliteExpenseRepository implements ExpenseRepository {
  SqliteExpenseRepository(this._appDatabase);
  final AppDatabase _appDatabase;

  @override
  Future<List<Expense>> getAll() async {
    final db = await _appDatabase.database;
    await _ensureKeys(db);
    final rows = await db.query('expenses', orderBy: 'date DESC, id DESC');
    return rows.map(Expense.fromMap).toList();
  }

  @override
  Future<int> add(Expense expense) async {
    final values = expense.toMap();
    values['import_key'] ??= _newRecordKey();
    return (await _appDatabase.database).insert('expenses', values);
  }

  @override
  Future<({int imported, int duplicates})> addImported(
      List<Expense> expenses) async {
    final db = await _appDatabase.database;
    var imported = 0;
    var duplicates = 0;
    await db.transaction((txn) async {
      for (final expense in expenses) {
        final key = expense.importKey;
        final existing = key == null
            ? null
            : await txn.query('expenses',
                columns: ['id'],
                where: 'import_key = ?',
                whereArgs: [key],
                limit: 1);
        if (existing != null && existing.isNotEmpty) {
          duplicates++;
          continue;
        }
        final id = await txn.insert('expenses', expense.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
        if (id == 0) {
          duplicates++;
        } else {
          imported++;
        }
      }
    });
    return (imported: imported, duplicates: duplicates);
  }

  @override
  Future<void> update(Expense expense) async {
    if (expense.id == null) {
      throw ArgumentError('An expense id is required to update it.');
    }
    final db = await _appDatabase.database;
    final values = expense.toMap();
    if (values['import_key'] == null) {
      final existing = await db.query('expenses',
          columns: ['import_key'], where: 'id = ?', whereArgs: [expense.id]);
      if (existing.isNotEmpty) {
        values['import_key'] = existing.first['import_key'];
      }
    }
    await db
        .update('expenses', values, where: 'id = ?', whereArgs: [expense.id]);
  }

  @override
  Future<void> delete(int id) async => (await _appDatabase.database)
      .delete('expenses', where: 'id = ?', whereArgs: [id]);

  Future<void> _ensureKeys(Database db) async {
    final rows = await db.query('expenses',
        columns: ['id'], where: 'import_key IS NULL');
    for (final row in rows) {
      await db.update('expenses', {'import_key': _newRecordKey()},
          where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  String _newRecordKey() {
    final random = Random.secure();
    final suffix = List.generate(
        16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    return 'pocket-expense:${suffix.join()}';
  }
}
