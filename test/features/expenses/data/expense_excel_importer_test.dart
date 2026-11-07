import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_expenses/features/expenses/data/expense_excel_importer.dart';
import 'package:pocket_expenses/features/expenses/data/expense_excel_exporter.dart';
import 'package:pocket_expenses/features/expenses/domain/expense.dart';
import 'package:pocket_expenses/features/expenses/domain/expense_category.dart';
import 'package:pocket_expenses/features/accounts/domain/money_account.dart';

void main() {
  test('keeps historical rows with a blank date or amount', () {
    final workbook = Excel.createExcel();
    final sheet = workbook['Transactions'];
    sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('Month');
    sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue('Date');
    sheet.cell(CellIndex.indexByString('C4')).value = TextCellValue('Purpose');
    sheet.cell(CellIndex.indexByString('D4')).value = TextCellValue('Amount');
    sheet.cell(CellIndex.indexByString('E4')).value =
        TextCellValue('Source row');
    sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('May 2026');
    sheet.cell(CellIndex.indexByString('B5')).value =
        const DateCellValue(year: 2026, month: 5, day: 3);
    sheet.cell(CellIndex.indexByString('C5')).value = TextCellValue('bus');
    sheet.cell(CellIndex.indexByString('D5')).value = const IntCellValue(55);
    sheet.cell(CellIndex.indexByString('E5')).value = const IntCellValue(8);
    sheet.cell(CellIndex.indexByString('B6')).value =
        const DateCellValue(year: 2026, month: 5, day: 4);
    sheet.cell(CellIndex.indexByString('D6')).value = const IntCellValue(0);
    sheet.cell(CellIndex.indexByString('B7')).value = TextCellValue('');
    sheet.cell(CellIndex.indexByString('C7')).value =
        TextCellValue('unknown date');
    sheet.cell(CellIndex.indexByString('D7')).value = const IntCellValue(25);
    sheet.cell(CellIndex.indexByString('E8')).value = const IntCellValue(11);

    final bytes = workbook.encode();
    final preview =
        const ExpenseExcelImporter().parse(Uint8List.fromList(bytes!));

    expect(preview.rows, hasLength(4));
    expect(preview.rows[0].expense.amount, 55);
    expect(preview.rows[0].expense.date, DateTime(2026, 5, 3));
    expect(preview.rows[0].expense.category, ExpenseCategory.other);
    expect(preview.rows[0].expense.note, 'bus');
    expect(preview.rows[0].expense.importKey, contains('8'));
    expect(preview.rows[1].expense.amount, 0);
    expect(preview.rows[1].expense.date, DateTime(2026, 5, 4));
    expect(preview.rows[2].expense.amount, 25);
    expect(preview.rows[2].expense.date, isNull);
    expect(preview.rows[3].expense.date, isNull);
    expect(preview.rows[3].expense.amount, isNull);
    expect(preview.skippedRows, 0);
  });

  test('round trips exported rows and retains category, account and import key',
      () {
    final bytes = const ExpenseExcelExporter().encode([
      Expense(
          id: 1,
          amount: 120.5,
          date: DateTime(2026, 5, 3),
          category: ExpenseCategory.transport,
          accountId: 7,
          note: 'Bus fare',
          importKey: 'pocket-expense:sample')
    ], {
      7: 'GCash'
    }, accounts: const [
      MoneyAccount(id: 7, name: 'GCash', balance: 450.25)
    ]);

    final preview = const ExpenseExcelImporter().parse(bytes);
    expect(preview.rows, hasLength(1));
    final row = preview.rows.single;
    expect(row.expense.amount, 120.5);
    expect(row.expense.date, DateTime(2026, 5, 3));
    expect(row.expense.category, ExpenseCategory.transport);
    expect(row.accountName, 'GCash');
    expect(row.expense.note, 'Bus fare');
    expect(row.expense.importKey, 'pocket-expense:sample');
    expect(preview.accounts, hasLength(1));
    expect(preview.accounts.single.name, 'GCash');
    expect(preview.accounts.single.balance, 450.25);
  });

  test('imports account balances without requiring expense rows', () {
    final bytes =
        const ExpenseExcelExporter().encode(const [], const {}, accounts: [
      const MoneyAccount(id: 4, name: 'Cash on Hand', balance: -15.75),
    ]);

    final preview = const ExpenseExcelImporter().parse(bytes);

    expect(preview.rows, isEmpty);
    expect(preview.accounts, hasLength(1));
    expect(preview.accounts.single.name, 'Cash on Hand');
    expect(preview.accounts.single.balance, -15.75);
  });
}
