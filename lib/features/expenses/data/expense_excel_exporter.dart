import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../accounts/domain/money_account.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';

class ExpenseExcelExporter {
  const ExpenseExcelExporter();

  Uint8List encode(
    Iterable<Expense> expenses,
    Map<int, String> accountNames, {
    Iterable<MoneyAccount> accounts = const [],
  }) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Expenses');
    final sheet = workbook['Expenses'];
    const headers = [
      'Date',
      'Amount',
      'Category',
      'Paid From',
      'Note',
      'Import Key',
    ];
    for (var column = 0; column < headers.length; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
          .value = TextCellValue(headers[column]);
      sheet.setColumnAutoFit(column);
    }

    var rowIndex = 1;
    for (final expense in expenses) {
      final values = <CellValue?>[
        expense.date == null ? null : TextCellValue(_dateKey(expense.date!)),
        expense.amount == null ? null : DoubleCellValue(expense.amount!),
        TextCellValue(expense.category.label),
        TextCellValue(accountNames[expense.accountId] ?? 'Unknown account'),
        expense.note == null ? null : TextCellValue(expense.note!),
        expense.importKey == null ? null : TextCellValue(expense.importKey!),
      ];
      for (var column = 0; column < values.length; column++) {
        final value = values[column];
        if (value != null) {
          sheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: column, rowIndex: rowIndex))
              .value = value;
        }
      }
      rowIndex++;
    }

    final accountsSheet = workbook['Accounts'];
    const accountHeaders = ['Account', 'Current Balance'];
    for (var column = 0; column < accountHeaders.length; column++) {
      accountsSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
          .value = TextCellValue(accountHeaders[column]);
      accountsSheet.setColumnAutoFit(column);
    }
    rowIndex = 1;
    for (final account in accounts) {
      accountsSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(account.name);
      accountsSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(account.balance);
      rowIndex++;
    }

    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Could not build the spreadsheet.');
    return Uint8List.fromList(bytes);
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
