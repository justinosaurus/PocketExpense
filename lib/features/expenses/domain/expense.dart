import 'expense_category.dart';

class Expense {
  const Expense(
      {required this.id,
      required this.amount,
      required this.date,
      required this.category,
      this.accountId = 1,
      this.note,
      this.importKey});

  final int? id;
  final double? amount;
  final DateTime? date;
  final ExpenseCategory category;
  final int accountId;
  final String? note;
  final String? importKey;

  Expense copyWith(
          {int? id,
          double? amount,
          DateTime? date,
          ExpenseCategory? category,
          int? accountId,
          String? note,
          String? importKey}) =>
      Expense(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        category: category ?? this.category,
        accountId: accountId ?? this.accountId,
        note: note ?? this.note,
        importKey: importKey ?? this.importKey,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'amount': amount,
        'date': date == null
            ? null
            : DateTime(date!.year, date!.month, date!.day).toIso8601String(),
        'category': category.name,
        'account_id': accountId,
        'note': note,
        'import_key': importKey,
      };

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
        id: map['id'] as int?,
        amount: (map['amount'] as num?)?.toDouble(),
        date:
            map['date'] == null ? null : DateTime.parse(map['date'] as String),
        category: ExpenseCategoryDetails.fromStorage(map['category'] as String),
        accountId: (map['account_id'] as int?) ?? 1,
        note: map['note'] as String?,
        importKey: map['import_key'] as String?,
      );
}
