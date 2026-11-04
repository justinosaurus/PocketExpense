import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../accounts/presentation/account_controller.dart';
import '../../expenses/domain/expense_analytics.dart';
import '../../expenses/domain/expense_category.dart';
import '../../expenses/presentation/expense_controller.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage(
      {super.key, required this.controller, required this.accountController});
  final ExpenseController controller;
  final AccountController accountController;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([controller, accountController]),
        builder: (context, _) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.error != null && controller.expenses.isEmpty) {
            return _ErrorState(
                message: controller.error!, onRetry: controller.load);
          }
          final now = DateTime.now();
          final month = ExpenseAnalytics.filter(controller.expenses,
              from: DateTime(now.year, now.month),
              to: DateTime(now.year, now.month + 1, 0));
          final categories = ExpenseAnalytics.byCategory(month).entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return RefreshIndicator(
            onRefresh: () async {
              await controller.load();
              await accountController.load();
            },
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                children: [
                  Text('Your money, at a glance',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.black54)),
                  const SizedBox(height: 14),
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available across accounts'),
                          const SizedBox(height: 6),
                          MoneyText(accountController.totalBalance,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          if (accountController.accounts.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...accountController.accounts
                                .map((account) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 3),
                                      child: Row(children: [
                                        Expanded(child: Text(account.name)),
                                        MoneyText(account.balance)
                                      ]),
                                    )),
                          ],
                        ]),
                  )),
                  const SizedBox(height: 14),
                  Card(
                    color: Theme.of(context).colorScheme.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Spent this month',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            MoneyText(ExpenseAnalytics.total(month),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text(
                                '${month.length} ${month.length == 1 ? 'expense' : 'expenses'} recorded',
                                style: const TextStyle(color: Colors.white70)),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Spending by category',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (categories.isEmpty)
                    const Card(
                        child: EmptyState(
                            title: 'Nothing this month yet',
                            message:
                                'Add an expense to see your spending summary.'))
                  else
                    ...categories.map((entry) {
                      final share = ExpenseAnalytics.total(month) == 0
                          ? 0.0
                          : entry.value / ExpenseAnalytics.total(month);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(children: [
                            Row(children: [
                              Icon(entry.key.icon,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(child: Text(entry.key.label)),
                              MoneyText(entry.value,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 10),
                            Semantics(
                                label:
                                    '${entry.key.label}: ${(share * 100).round()} percent',
                                child: LinearProgressIndicator(
                                    value: share,
                                    minHeight: 5,
                                    borderRadius: BorderRadius.circular(5))),
                          ]),
                        ),
                      );
                    }),
                  if (controller.error != null)
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(controller.error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                ]),
          );
        },
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again')),
        ]),
      ));
}
