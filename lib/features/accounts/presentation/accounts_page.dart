import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../domain/account_movement.dart';
import '../domain/money_account.dart';
import 'account_action_page.dart';
import 'account_controller.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, required this.controller});
  final AccountController controller;

  Future<void> _addAccount(BuildContext context) async {
    final name = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Add money account'),
              content: TextField(
                  controller: name,
                  autofocus: true,
                  maxLength: 32,
                  decoration: const InputDecoration(
                      labelText: 'Account name', hintText: 'e.g. E-wallet')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, name.text),
                    child: const Text('Add'))
              ],
            ));
    name.dispose();
    if (value == null || !context.mounted) return;
    try {
      await controller.addAccount(value);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _removeAccount(
      BuildContext context, MoneyAccount account) async {
    String? blocker;
    try {
      blocker = await controller.accountRemovalBlocker(account.id);
    } catch (error) {
      if (context.mounted) _showError(context, error);
      return;
    }
    if (!context.mounted) return;
    if (blocker != null) {
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Account not removed'),
                content: Text(blocker!),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK')),
                ],
              ));
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Remove account?'),
              content: Text(
                  'Remove ${account.name}? This account has no expenses or money movements.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove')),
              ],
            ));
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.deleteAccount(account.id);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, Object error) {
    final message = error
        .toString()
        .replaceFirst(RegExp(r'^(Invalid argument\(s\): |Bad state: )'), '');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAction(BuildContext context,
      {required bool transfer, int? accountId}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AccountActionPage(
          controller: controller,
          transfer: transfer,
          initialAccountId: accountId),
    ));
    if (saved == true) await controller.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isLoading && controller.accounts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.error != null && controller.accounts.isEmpty) {
            return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(controller.error!),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: controller.load, child: const Text('Try again'))
            ]));
          }
          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                children: [
                  Text('Your accounts',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  Card(
                      color: Theme.of(context).colorScheme.primary,
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total across accounts',
                                  style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              MoneyText(controller.totalBalance,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text(
                                  'Balances update with expenses, transfers, and adjustments.',
                                  style: TextStyle(color: Colors.white70)),
                            ]),
                      )),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                        onPressed: () => _openAction(context, transfer: true),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Transfer')),
                    OutlinedButton.icon(
                        onPressed: () => _openAction(context, transfer: false),
                        icon: const Icon(Icons.tune),
                        label: const Text('Adjust balance')),
                    OutlinedButton.icon(
                        onPressed: () => _addAccount(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add account')),
                  ]),
                  const SizedBox(height: 20),
                  Text('Balances',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...controller.accounts.map((account) => _AccountCard(
                      account: account,
                      onAdjust: () => _openAction(context,
                          transfer: false, accountId: account.id),
                      onRemove: () => _removeAccount(context, account))),
                  const SizedBox(height: 20),
                  Text('Recent money movements',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (controller.movements.isEmpty)
                    const Card(
                        child: EmptyState(
                            icon: Icons.swap_horiz,
                            title: 'No movements yet',
                            message:
                                'Transfers and balance adjustments will appear here.'))
                  else
                    ...controller.movements
                        .take(12)
                        .map((movement) => _MovementTile(movement: movement)),
                ]),
          );
        },
      );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard(
      {required this.account, required this.onAdjust, required this.onRemove});
  final MoneyAccount account;
  final VoidCallback onAdjust;
  final VoidCallback onRemove;

  IconData get _icon {
    final name = account.name.toLowerCase();
    if (name.contains('cash')) return Icons.payments_outlined;
    if (name.contains('gcash')) return Icons.phone_android;
    if (name.contains('saving')) return Icons.savings_outlined;
    return Icons.account_balance_wallet_outlined;
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child:
                    Icon(_icon, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(account.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Text('Available balance'),
                  const SizedBox(height: 4),
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: MoneyText(account.balance,
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                ])),
            const SizedBox(width: 4),
            Column(mainAxisSize: MainAxisSize.min, children: [
              TextButton(
                  onPressed: onAdjust,
                  style: TextButton.styleFrom(
                      minimumSize: const Size(44, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('Adjust')),
              PopupMenuButton<String>(
                  tooltip: 'Account options',
                  onSelected: (value) {
                    if (value == 'remove') onRemove();
                  },
                  itemBuilder: (context) => const [
                        PopupMenuItem(
                            value: 'remove',
                            child: ListTile(
                                leading: Icon(Icons.delete_outline),
                                title: Text('Remove account'))),
                      ]),
            ]),
          ]),
        ),
      );
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});
  final AccountMovement movement;

  @override
  Widget build(BuildContext context) {
    final title =
        movement.type == 'transfer' ? 'Transfer' : 'Balance adjustment';
    final route = movement.type == 'transfer'
        ? '${movement.fromName ?? 'Account'} → ${movement.toName ?? 'Account'}'
        : movement.toName != null
            ? 'Added to ${movement.toName}'
            : 'Taken from ${movement.fromName}';
    return Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          leading: Icon(
              movement.type == 'transfer' ? Icons.swap_horiz : Icons.tune,
              color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(
              '${movement.note?.isNotEmpty == true ? '${movement.note} · ' : ''}$route · ${movement.date.day}/${movement.date.month}/${movement.date.year}'),
          trailing: MoneyText(movement.amount),
        ));
  }
}
