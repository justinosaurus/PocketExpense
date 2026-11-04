import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../accounts/presentation/account_controller.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../data/expense_excel_importer.dart';
import '../data/expense_excel_exporter.dart';
import '../domain/expense.dart';
import '../domain/expense_analytics.dart';
import '../domain/expense_category.dart';
import 'expense_controller.dart';
import 'expense_form_page.dart';

class ExpenseHistoryPage extends StatefulWidget {
  const ExpenseHistoryPage(
      {super.key, required this.controller, required this.accountController});
  final ExpenseController controller;
  final AccountController accountController;
  @override
  State<ExpenseHistoryPage> createState() => _ExpenseHistoryPageState();
}

class _ExpenseHistoryPageState extends State<ExpenseHistoryPage> {
  ExpenseCategory? _category;
  DateTimeRange? _range;
  int? _accountId;
  bool _importing = false;

  String _accountName(int id) {
    for (final account in widget.accountController.accounts) {
      if (account.id == id) return account.name;
    }
    return 'Unknown account';
  }

  Future<void> _edit(Expense expense) async {
    if (widget.accountController.accounts.isEmpty) {
      await widget.accountController.load();
    }
    if (!mounted) return;
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ExpenseFormPage(
          controller: widget.controller,
          accountController: widget.accountController,
          expense: expense),
    ));
  }

  Future<void> _importWorkbook() async {
    if (widget.accountController.accounts.isEmpty) {
      await widget.accountController.load();
    }
    if (!mounted || widget.accountController.accounts.isEmpty) return;
    try {
      final file = await FilePicker.pickFile(
          type: FileType.custom, allowedExtensions: ['xlsx']);
      if (file == null || !mounted) return;
      setState(() => _importing = true);
      final preview =
          const ExpenseExcelImporter().parse(await file.readAsBytes());
      if (preview.rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'No expense records were found. ${preview.skippedRows} invalid rows were skipped.')));
        }
        return;
      }
      final incomplete = preview.rows
          .where(
              (row) => row.expense.date == null || row.expense.amount == null)
          .length;
      final unmatched = preview.rows.where((row) =>
          row.accountName == null ||
          _accountIdForName(row.accountName!) == null);
      final fallbackCount = unmatched.length;
      final fallbackAccountId = fallbackCount == 0
          ? widget.accountController.accounts.first.id
          : await _chooseImportAccount(fallbackCount);
      if (fallbackAccountId == null || !mounted) return;
      final expenses = preview.rows
          .map((row) => row.expense.copyWith(
              accountId: _accountIdForName(row.accountName ?? '') ??
                  fallbackAccountId))
          .toList();
      final result = await widget.controller.importExpenses(expenses);
      if (mounted) {
        setState(() => _accountId =
            fallbackCount == preview.rows.length ? fallbackAccountId : null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Imported ${result.imported} records. ${result.duplicates} already existed; $incomplete need a date or amount; ${preview.skippedRows} invalid rows skipped.')));
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not import this file. Choose the organized Finance workbook and try again.')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  int? _accountIdForName(String name) {
    for (final account in widget.accountController.accounts) {
      if (account.name.trim().toLowerCase() == name.trim().toLowerCase()) {
        return account.id;
      }
    }
    return null;
  }

  Future<void> _exportWorkbook() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final bytes =
          const ExpenseExcelExporter().encode(widget.controller.expenses, {
        for (final account in widget.accountController.accounts)
          account.id: account.name
      });
      final saved = await FilePicker.saveFile(
          fileName: 'pocket_expenses.xlsx',
          bytes: bytes,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          dialogTitle: 'Export expense spreadsheet');
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense spreadsheet saved.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not export the spreadsheet. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<int?> _chooseImportAccount(int unmatchedCount) async {
    final accounts = widget.accountController.accounts;
    var selected = accounts.first.id;
    return showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Where did these expenses come from?'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (unmatchedCount > 0)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                              '$unmatchedCount records have no matching account name. Assign those rows below. Blank dates and amounts can be completed from History.')),
                    DropdownButton<int>(
                        value: selected,
                        isExpanded: true,
                        items: accounts
                            .map((account) => DropdownMenuItem(
                                value: account.id, child: Text(account.name)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selected = value);
                          }
                        }),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, selected),
                        child: const Text('Continue'))
                  ],
                )));
  }

  Future<void> _delete(Expense expense) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete expense?'),
              content:
                  const Text('This expense will be removed from your history.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'))
              ],
            ));
    if (confirm == true && mounted) {
      try {
        await widget.controller.remove(expense);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not delete expense. Please try again.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation:
            Listenable.merge([widget.controller, widget.accountController]),
        builder: (context, _) {
          if (widget.controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final expenses = ExpenseAnalytics.filter(widget.controller.expenses,
                  from: _range?.start, to: _range?.end, category: _category)
              .where((expense) =>
                  _accountId == null || expense.accountId == _accountId)
              .toList();
          return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
              children: [
                Text('Expense history',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(
                      onPressed: _importing ? null : _importWorkbook,
                      icon: _importing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.file_upload_outlined),
                      label: const Text('Import')),
                  OutlinedButton.icon(
                      onPressed: _importing ? null : _exportWorkbook,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Export')),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: _range);
                      if (picked != null) setState(() => _range = picked);
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(_range == null
                        ? 'Any date'
                        : '${_date(_range!.start)} – ${_date(_range!.end)}'),
                  ),
                  DropdownButton<ExpenseCategory?>(
                    value: _category,
                    hint: const Text('All categories'),
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<ExpenseCategory?>(
                          value: null, child: Text('All categories')),
                      ...ExpenseCategory.values.map((c) =>
                          DropdownMenuItem(value: c, child: Text(c.label)))
                    ],
                    onChanged: (value) => setState(() => _category = value),
                  ),
                  DropdownButton<int?>(
                    value: _accountId,
                    hint: const Text('All accounts'),
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('All accounts')),
                      ...widget.accountController.accounts.map((account) =>
                          DropdownMenuItem<int?>(
                              value: account.id, child: Text(account.name)))
                    ],
                    onChanged: (value) => setState(() => _accountId = value),
                  ),
                  if (_range != null || _category != null || _accountId != null)
                    TextButton(
                        onPressed: () => setState(() {
                              _range = null;
                              _category = null;
                              _accountId = null;
                            }),
                        child: const Text('Clear filters')),
                ]),
                const SizedBox(height: 8),
                if (widget.controller.error != null)
                  Text(widget.controller.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (expenses.isEmpty)
                  Card(
                      child: EmptyState(
                          title: widget.controller.expenses.isEmpty
                              ? 'No expenses yet'
                              : 'No matching expenses',
                          message: widget.controller.expenses.isEmpty
                              ? 'Tap “Add expense” to record your first one.'
                              : 'Try changing or clearing your filters.'))
                else
                  ...expenses.map((expense) => _ExpenseTile(
                        expense: expense,
                        accountName: _accountName(expense.accountId),
                        onTap: () => _edit(expense),
                        onDelete: () => _delete(expense),
                      )),
              ]);
        },
      );
}

String _date(DateTime? date) => date == null
    ? 'Date not entered'
    : '${date.day}/${date.month}/${date.year}';

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile(
      {required this.expense,
      required this.accountName,
      required this.onTap,
      required this.onDelete});
  final Expense expense;
  final String accountName;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          minVerticalPadding: 12,
          leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(expense.category.icon,
                  color: Theme.of(context).colorScheme.primary)),
          title: Text(
              expense.note?.isNotEmpty == true
                  ? expense.note!
                  : expense.category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '${expense.category.label} · $accountName · ${_date(expense.date)}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            expense.amount == null
                ? const SizedBox(
                    width: 86,
                    child: Text('Amount not entered',
                        maxLines: 2,
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 12)))
                : MoneyText(expense.amount!,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
            PopupMenuButton<String>(
                tooltip: 'Expense actions',
                onSelected: (value) {
                  if (value == 'edit') onTap();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete'))
                    ]),
          ]),
          onTap: onTap,
        ),
      );
}
