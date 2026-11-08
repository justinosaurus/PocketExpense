import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../analytics/domain/analytics_data.dart';
import '../../analytics/presentation/analytics_page.dart';
import '../../accounts/presentation/account_controller.dart';
import '../../expenses/domain/expense_category.dart';
import '../../expenses/presentation/expense_controller.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.controller,
    required this.accountController,
    required this.onOpenAnalytics,
  });

  final ExpenseController controller;
  final AccountController accountController;
  final ValueChanged<AnalyticsFocus> onOpenAnalytics;

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
          final range = AnalyticsDateRange.current(AnalyticsPeriod.month, now);
          final analytics = AnalyticsData(
            expenses: controller.expenses,
            movements: accountController.movements,
            accounts: accountController.accounts,
            range: range,
          );
          final previous = analytics.previousPeriod(
            allExpenses: controller.expenses,
            allMovements: accountController.movements,
            accounts: accountController.accounts,
          );
          final categories = analytics.spendingByCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return RefreshIndicator(
            onRefresh: () async {
              await controller.load();
              await accountController.load();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
              children: [
                Text('Your money, at a glance',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _SummaryGrid(
                  analytics: analytics,
                  previous: previous,
                  onTap: onOpenAnalytics,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available across accounts'),
                        const SizedBox(height: 6),
                        MoneyText(
                          accountController.totalBalance,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (accountController.accounts.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...accountController.accounts
                              .map((account) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(children: [
                                      Expanded(child: Text(account.name)),
                                      MoneyText(account.balance),
                                    ]),
                                  )),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: Text('Spending by category',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => onOpenAnalytics(AnalyticsFocus.expenses),
                    child: const Text('Details'),
                  ),
                ]),
                const SizedBox(height: 8),
                if (categories.isEmpty)
                  const Card(
                    child: EmptyState(
                      title: 'Nothing this month yet',
                      message: 'Add an expense to see your spending summary.',
                    ),
                  )
                else
                  ...categories.map((entry) {
                    final share = analytics.expenseTotal == 0
                        ? 0.0
                        : entry.value / analytics.expenseTotal;
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
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ]),
                      ),
                    );
                  }),
                if (controller.error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      controller.error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (accountController.error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      accountController.error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.analytics,
    required this.previous,
    required this.onTap,
  });

  final AnalyticsData analytics;
  final AnalyticsData previous;
  final ValueChanged<AnalyticsFocus> onTap;

  @override
  Widget build(BuildContext context) {
    final rate = analytics.savingsRate;
    final previousRate = previous.savingsRate;
    final tiles = [
      _SummaryTile(
        label: 'Income',
        amount: analytics.incomeTotal,
        icon: Icons.south_west,
        period: 'This month',
        change: _change(analytics.incomeTotal, previous.incomeTotal),
        onTap: () => onTap(AnalyticsFocus.income),
      ),
      _SummaryTile(
        label: 'Spending',
        amount: analytics.expenseTotal,
        icon: Icons.north_east,
        period: 'This month',
        change: _change(analytics.expenseTotal, previous.expenseTotal),
        onTap: () => onTap(AnalyticsFocus.expenses),
      ),
      _SummaryTile(
        label: 'Cash flow',
        amount: analytics.netCashFlow,
        icon: Icons.compare_arrows,
        period: 'This month',
        change:
            '${_signed(analytics.netCashFlow - previous.netCashFlow)} vs prior',
        onTap: () => onTap(AnalyticsFocus.cashFlow),
      ),
      _SummaryTile(
        label: 'Savings rate',
        amount: rate == null ? null : rate * 100,
        suffix: '%',
        icon: Icons.savings_outlined,
        period: 'Net ÷ income',
        change: rate == null || previousRate == null
            ? 'Needs income'
            : '${_signed((rate - previousRate) * 100)} pp vs prior',
        onTap: () => onTap(AnalyticsFocus.savingsRate),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              tiles.map((tile) => SizedBox(width: width, child: tile)).toList(),
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.period,
    required this.change,
    required this.onTap,
    this.suffix,
  });

  final String label;
  final double? amount;
  final IconData icon;
  final String period;
  final String change;
  final VoidCallback onTap;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 19, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(label)),
              ]),
              const SizedBox(height: 10),
              if (amount == null)
                Text('—',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold))
              else if (suffix != null)
                Text('${amount!.toStringAsFixed(1)}$suffix',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold))
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(
                    amount!,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                period,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                change,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
              label: const Text('Try again'),
            ),
          ]),
        ),
      );
}

String _change(double current, double previous) {
  if (previous == 0) {
    return current == 0 ? 'No change vs prior' : 'New this month';
  }
  final percent = (current - previous) / previous.abs() * 100;
  return '${percent >= 0 ? '↑' : '↓'} ${percent.abs().toStringAsFixed(1)}% vs prior';
}

String _signed(double value) =>
    '${value >= 0 ? '+' : '−'}₱${value.abs().toStringAsFixed(2)}';
