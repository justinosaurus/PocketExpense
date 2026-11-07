import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = p.join(await getDatabasesPath(), 'pocket_expenses.db');
    _database =
        await openDatabase(path, version: 5, onCreate: (db, version) async {
      await db.execute('''CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )''');
      await db.insert('accounts', {'id': 1, 'name': 'Cash on Hand'});
      await db.insert('accounts', {'id': 2, 'name': 'GCash'});
      await db.insert('accounts', {'id': 3, 'name': 'Savings Account'});
      await _createExpensesTable(db);
      await _createExpenseIndexes(db);
      await _createMovementsTable(db);
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('''CREATE TABLE accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
        )''');
        await db.insert('accounts', {'id': 1, 'name': 'Cash on Hand'});
        await db.insert('accounts', {'id': 2, 'name': 'GCash'});
        await db.insert('accounts', {'id': 3, 'name': 'Savings Account'});
        await db.execute(
            'ALTER TABLE expenses ADD COLUMN account_id INTEGER NOT NULL DEFAULT 1');
      }
      if (oldVersion < 3) {
        await db.execute('ALTER TABLE expenses ADD COLUMN import_key TEXT');
        await db.execute(
            'CREATE UNIQUE INDEX expenses_import_key_idx ON expenses(import_key) WHERE import_key IS NOT NULL');
        await _createMovementsTable(db);
      }
      if (oldVersion < 4) {
        await db.execute(
            'ALTER TABLE expenses RENAME TO expenses_before_incomplete');
        await _createExpensesTable(db);
        await db.execute(
            '''INSERT INTO expenses (id, amount, date, category, note, account_id, import_key)
          SELECT id, amount, date, category, note, account_id, import_key FROM expenses_before_incomplete''');
        await db.execute('DROP TABLE expenses_before_incomplete');
        await _createExpenseIndexes(db);
      }
      if (oldVersion < 5) {
        final expenses = await db.query('expenses',
            columns: ['id'], where: 'import_key IS NULL');
        for (final expense in expenses) {
          await db.update('expenses', {'import_key': _newRecordKey()},
              where: 'id = ?', whereArgs: [expense['id']]);
        }
      }
      if (oldVersion < 6) {
        await db.execute(
            'ALTER TABLE account_movements RENAME TO account_movements_before_income');
        await _createMovementsTable(db);
        await db.execute('''
          INSERT INTO account_movements
            (id, type, from_account_id, to_account_id, amount, date, note)
          SELECT id, type, from_account_id, to_account_id, amount, date, note
          FROM account_movements_before_income
        ''');
        await db.execute('DROP TABLE account_movements_before_income');
      }
    });
    return _database!;
  }

  static Future<void> _createExpensesTable(Database db) async {
    await db.execute('''CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL CHECK(amount IS NULL OR amount >= 0),
      date TEXT,
      category TEXT NOT NULL,
      note TEXT,
      account_id INTEGER NOT NULL DEFAULT 1 REFERENCES accounts(id),
      import_key TEXT
    )''');
  }

  static Future<void> _createExpenseIndexes(Database db) async {
    await db.execute('CREATE INDEX expenses_date_idx ON expenses(date)');
    await db.execute(
        'CREATE UNIQUE INDEX expenses_import_key_idx ON expenses(import_key) WHERE import_key IS NOT NULL');
  }

  static Future<void> _createMovementsTable(Database db) async {
    await db.execute('''CREATE TABLE account_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL CHECK(type IN ('transfer', 'adjustment', 'income')),
      from_account_id INTEGER REFERENCES accounts(id),
      to_account_id INTEGER REFERENCES accounts(id),
      amount REAL NOT NULL CHECK(amount > 0),
      date TEXT NOT NULL,
      note TEXT,
      CHECK(from_account_id IS NOT NULL OR to_account_id IS NOT NULL),
      CHECK(from_account_id IS NULL OR to_account_id IS NULL OR from_account_id <> to_account_id)
    )''');
  }

  static String _newRecordKey() {
    final random = Random.secure();
    final suffix = List.generate(
        16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    return 'pocket-expense:${suffix.join()}';
  }
}
