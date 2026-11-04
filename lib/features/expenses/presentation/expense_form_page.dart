import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../accounts/presentation/account_controller.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import 'expense_controller.dart';

class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage(
      {super.key,
      required this.controller,
      required this.accountController,
      this.expense});
  final ExpenseController controller;
  final AccountController accountController;
  final Expense? expense;
  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  DateTime? _date;
  late ExpenseCategory _category;
  late int _accountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _amount =
        TextEditingController(text: expense?.amount?.toStringAsFixed(2) ?? '');
    _note = TextEditingController(text: expense?.note ?? '');
    _date = expense?.date ?? (expense == null ? DateTime.now() : null);
    _category = expense?.category ?? ExpenseCategory.food;
    _accountId = expense?.accountId ??
        (widget.accountController.accounts.isEmpty
            ? 1
            : widget.accountController.accounts.first.id);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amountText = _amount.text.trim();
    final expense = Expense(
        id: widget.expense?.id,
        amount: amountText.isEmpty ? null : double.parse(amountText),
        date: _date,
        category: _category,
        accountId: _accountId,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        importKey: widget.expense?.importKey);
    try {
      await widget.controller.save(expense);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save expense. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title:
                Text(widget.expense == null ? 'Add expense' : 'Edit expense')),
        body: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₱ ',
                  helperText: 'Enter an amount greater than zero'),
              validator: (value) {
                final allowIncomplete = widget.expense?.importKey != null;
                if (allowIncomplete && (value?.trim().isEmpty ?? true)) {
                  return null;
                }
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null ||
                    !amount.isFinite ||
                    (allowIncomplete ? amount < 0 : amount <= 0)) {
                  return allowIncomplete
                      ? 'Enter zero or a valid positive amount'
                      : 'Enter a valid amount greater than zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ExpenseCategory.values
                  .map((category) => DropdownMenuItem(
                      value: category, child: Text(category.label)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Paid from'),
              items: widget.accountController.accounts
                  .map((account) => DropdownMenuItem(
                      value: account.id, child: Text(account.name)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _accountId = value);
              },
            ),
            const SizedBox(height: 18),
            Semantics(
                label: 'Expense date',
                button: true,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate: _date ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now());
                    if (date != null) setState(() => _date = date);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_date == null
                      ? 'Date not entered'
                      : 'Date: ${_date!.day}/${_date!.month}/${_date!.year}'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                )),
            if (widget.expense?.importKey != null && _date != null)
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: () => setState(() => _date = null),
                      child: const Text('Clear date'))),
            const SizedBox(height: 18),
            TextFormField(
                controller: _note,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'What was this for?')),
            const SizedBox(height: 22),
            FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.expense == null
                        ? 'Save expense'
                        : 'Save changes')),
          ]),
        ),
      );
}
