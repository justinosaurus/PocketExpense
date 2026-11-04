import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../domain/expense.dart';
import '../domain/expense_category.dart';

class ExpenseImportRow {
  const ExpenseImportRow({required this.expense, this.accountName});

  final Expense expense;
  final String? accountName;
}

class ExpenseImportPreview {
  const ExpenseImportPreview({required this.rows, required this.skippedRows});

  final List<ExpenseImportRow> rows;
  final int skippedRows;
}

/// Reads both this app's exports and common personal finance workbook layouts.
class ExpenseExcelImporter {
  const ExpenseExcelImporter();

  ExpenseImportPreview parse(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final sheets = workbook.tables.entries.toList()
      ..sort((a, b) => _sheetPriority(a.key).compareTo(_sheetPriority(b.key)));
    for (final entry in sheets) {
      final parsed = _parseSheet(entry.value);
      if (parsed != null) return parsed;
    }
    throw const FormatException(
        'No expense sheet found. Include columns such as Amount, Date, Note, or Purpose.');
  }

  int _sheetPriority(String name) {
    switch (_normalize(name)) {
      case 'expenses':
        return 0;
      case 'transactions':
        return 1;
      default:
        return 2;
    }
  }

  ExpenseImportPreview? _parseSheet(Sheet sheet) {
    final rows = sheet.rows;
    var headerIndex = -1;
    var columns = <String, int>{};
    for (var index = 0; index < rows.length && index < 30; index++) {
      final headers = rows[index].map(_cellText).toList();
      final found = <String, int>{};
      for (var column = 0; column < headers.length; column++) {
        final header = _normalize(headers[column] ?? '');
        if (header.isEmpty) continue;
        final field = _headerField(header);
        if (field != null) found.putIfAbsent(field, () => column);
      }
      if (found.containsKey('amount') &&
          (found.containsKey('date') ||
              found.containsKey('note') ||
              found.containsKey('category'))) {
        headerIndex = index;
        columns = found;
        break;
      }
    }
    if (headerIndex < 0) return null;

    final parsed = <ExpenseImportRow>[];
    var skipped = 0;
    for (var rowIndex = headerIndex + 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final rawAmount = _cellText(_at(row, columns['amount']));
      final amount = _cellNumber(_at(row, columns['amount']));
      final rawDate = _cellText(_at(row, columns['date']));
      final date = _cellDate(_at(row, columns['date']));
      final note = _cellText(_at(row, columns['note']))?.trim();
      final categoryText = _cellText(_at(row, columns['category']))?.trim();
      final accountName = _cellText(_at(row, columns['account']))?.trim();
      final importedKey = _cellText(_at(row, columns['importKey']))?.trim();
      final sourceRow = _cellText(_at(row, columns['sourceRow']))?.trim();
      final hasRecordData = [
        rawAmount,
        rawDate,
        note,
        categoryText,
        accountName,
        sourceRow
      ].any((value) => value != null && value.isNotEmpty);
      if (!hasRecordData) continue;

      if (rawAmount != null && rawAmount.trim().isNotEmpty && amount == null) {
        skipped++;
        continue;
      }
      if (amount != null && (!amount.isFinite || amount < 0)) {
        skipped++;
        continue;
      }

      final category = _category(categoryText);
      final cleanNote = note == null || note.isEmpty ? null : note;
      final cleanAccount =
          accountName == null || accountName.isEmpty ? null : accountName;
      final key = importedKey != null && importedKey.isNotEmpty
          ? importedKey
          : sourceRow != null && sourceRow.isNotEmpty
              ? 'finance-xlsx:$sourceRow:${date == null ? 'missing-date' : _dateKey(date)}:${amount?.toStringAsFixed(2) ?? 'missing-amount'}:${cleanNote ?? ''}'
              : 'spreadsheet-row:${rowIndex + 1}:${date == null ? 'no-date' : _dateKey(date)}:${amount?.toStringAsFixed(2) ?? 'no-amount'}:${category.name}:${cleanNote ?? ''}';
      parsed.add(ExpenseImportRow(
        expense: Expense(
          id: null,
          amount: amount,
          date: date,
          category: category,
          note: cleanNote,
          importKey: key,
        ),
        accountName: cleanAccount,
      ));
    }
    return ExpenseImportPreview(rows: parsed, skippedRows: skipped);
  }

  String? _headerField(String value) {
    if (const {'date', 'transactiondate', 'expensedate'}.contains(value)) {
      return 'date';
    }
    if (const {'amount', 'value', 'cost', 'total'}.contains(value)) {
      return 'amount';
    }
    if (const {'purpose', 'note', 'notes', 'description', 'details', 'memo'}
        .contains(value)) {
      return 'note';
    }
    if (const {'category', 'type'}.contains(value)) return 'category';
    if (const {'account', 'paidfrom', 'source', 'paymentmethod'}
        .contains(value)) {
      return 'account';
    }
    if (const {'importkey', 'recordkey', 'exportkey'}.contains(value)) {
      return 'importKey';
    }
    if (value == 'sourcerow') return 'sourceRow';
    return null;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  ExpenseCategory _category(String? value) {
    if (value == null || value.isEmpty) return ExpenseCategory.other;
    final normalized = _normalize(value);
    for (final category in ExpenseCategory.values) {
      if (_normalize(category.name) == normalized ||
          _normalize(category.label) == normalized) {
        return category;
      }
    }
    return ExpenseCategory.other;
  }

  Data? _at(List<Data?> row, int? index) =>
      index == null || index < 0 || index >= row.length ? null : row[index];

  String? _cellText(Data? cell) {
    final value = cell?.value;
    if (value == null || value is FormulaCellValue) return null;
    if (value is TextCellValue) return value.value.toString();
    if (value is DateCellValue || value is DateTimeCellValue) {
      final date = value is DateCellValue
          ? value.asDateTimeLocal()
          : (value as DateTimeCellValue).asDateTimeLocal();
      return _dateKey(date);
    }
    return value.toString();
  }

  double? _cellNumber(Data? cell) {
    final value = cell?.value;
    if (value is IntCellValue) return value.value.toDouble();
    if (value is DoubleCellValue) return value.value;
    if (value is TextCellValue) {
      var text = value.value.toString().trim();
      final negative = text.startsWith('(') && text.endsWith(')');
      text = text.replaceAll(RegExp(r'[^0-9.\-]'), '');
      final number = double.tryParse(text);
      if (number == null) return null;
      return negative ? -number.abs() : number;
    }
    return null;
  }

  DateTime? _cellDate(Data? cell) {
    final value = cell?.value;
    if (value is DateCellValue) return _dateOnly(value.asDateTimeLocal());
    if (value is DateTimeCellValue) return _dateOnly(value.asDateTimeLocal());
    if (value is IntCellValue && value.value > 30000) {
      return _fromExcelSerial(value.value.toDouble());
    }
    if (value is DoubleCellValue && value.value > 30000) {
      return _fromExcelSerial(value.value);
    }
    if (value is TextCellValue) {
      return _parseTextDate(value.value.toString().trim());
    }
    return null;
  }

  DateTime? _parseTextDate(String value) {
    final iso = DateTime.tryParse(value);
    if (iso != null) return _dateOnly(iso);
    final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(value);
    if (match == null) return null;
    final month = int.parse(match.group(1)!);
    final day = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += year < 50 ? 2000 : 1900;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _fromExcelSerial(double value) =>
      _dateOnly(DateTime(1899, 12, 30).add(Duration(
          milliseconds: (value * Duration.millisecondsPerDay).round())));

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
