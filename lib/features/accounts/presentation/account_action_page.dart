import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/money_text.dart';
import '../domain/money_account.dart';
import 'account_controller.dart';

class AccountActionPage extends StatefulWidget {
  const AccountActionPage(
      {super.key,
      required this.controller,
      required this.transfer,
      this.initialAccountId});
  final AccountController controller;
  final bool transfer;
  final int? initialAccountId;

  @override
  State<AccountActionPage> createState() => _AccountActionPageState();
}

class _AccountActionPageState extends State<AccountActionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late int _fromAccountId;
  late int _toAccountId;
  bool _adding = true;
  bool _saving = false;
  DateTime _date = DateTime.now();

  List<MoneyAccount> get _accounts => widget.controller.accounts;

  @override
  void initState() {
    super.initState();
    final first =
        widget.initialAccountId ?? (_accounts.isEmpty ? 1 : _accounts.first.id);
    _fromAccountId = first;
    final otherAccounts =
        _accounts.where((account) => account.id != first).toList();
    _toAccountId = otherAccounts.isEmpty ? first : otherAccounts.first.id;
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
    final amount = double.parse(_amount.text.trim());
    try {
      if (widget.transfer) {
        await widget.controller.transfer(
            fromAccountId: _fromAccountId,
            toAccountId: _toAccountId,
            amount: amount,
            date: _date,
            note: _note.text.trim());
      } else {
        await widget.controller.adjust(
            accountId: _fromAccountId,
            change: _adding ? amount : -amount,
            date: _date,
            note: _note.text.trim());
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                error.toString().replaceFirst('Invalid argument(s): ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2000),
        lastDate: DateTime.now());
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (_accounts.isEmpty) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.transfer ? 'Transfer money' : 'Adjust balance')),
      body: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            if (widget.transfer) ...[
              DropdownButtonFormField<int>(
                  initialValue: _fromAccountId,
                  decoration: const InputDecoration(labelText: 'From'),
                  items: _accounts
                      .map((account) => DropdownMenuItem(
                          value: account.id, child: Text(account.name)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _fromAccountId = value);
                  }),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                  initialValue: _toAccountId,
                  decoration: const InputDecoration(labelText: 'To'),
                  items: _accounts
                      .map((account) => DropdownMenuItem(
                          value: account.id, child: Text(account.name)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _toAccountId = value);
                  },
                  validator: (value) => value == _fromAccountId
                      ? 'Choose a different destination account'
                      : null),
              const SizedBox(height: 16),
            ] else ...[
              DropdownButtonFormField<int>(
                  initialValue: _fromAccountId,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: _accounts
                      .map((account) => DropdownMenuItem(
                          value: account.id,
                          child: Text(
                              '${account.name} · ${formatMoney(account.balance)}')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _fromAccountId = value);
                  }),
              const SizedBox(height: 18),
              SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: true,
                        label: Text('Add money'),
                        icon: Icon(Icons.add)),
                    ButtonSegment(
                        value: false,
                        label: Text('Take out'),
                        icon: Icon(Icons.remove))
                  ],
                  selected: {
                    _adding
                  },
                  onSelectionChanged: (values) =>
                      setState(() => _adding = values.first)),
              const SizedBox(height: 16),
            ],
            TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Amount', prefixText: '₱ '),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  return parsed == null || !parsed.isFinite || parsed <= 0
                      ? 'Enter an amount greater than zero'
                      : null;
                }),
            const SizedBox(height: 16),
            OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text('Date: ${_date.day}/${_date.month}/${_date.year}'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52))),
            const SizedBox(height: 16),
            TextFormField(
                controller: _note,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. Starting balance or ATM withdrawal')),
            if (widget.transfer && amount > 0 && _fromAccountId == _toAccountId)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Choose two different accounts.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.transfer
                        ? 'Record transfer'
                        : 'Save adjustment')),
          ])),
    );
  }
}
