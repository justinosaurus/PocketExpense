import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../accounts/domain/account_movement.dart';
import '../../accounts/domain/money_account.dart';
import '../../accounts/presentation/account_controller.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_category.dart';
import '../../expenses/presentation/expense_controller.dart';
import '../domain/analytics_data.dart';

enum AnalyticsFocus { income, expenses, cashFlow, savingsRate }

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({
    super.key,
    required this.controller,
    required this.accountController,
    required this.onAddExpense,
    this.focus = AnalyticsFocus.expenses,
  });

  final ExpenseController controller;
  final AccountController accountController;
  final VoidCallback onAddExpense;
  final AnalyticsFocus focus;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  AnalyticsPeriod _period = AnalyticsPeriod.month;
  late AnalyticsDateRange _range;
  int? _accountId;
  ExpenseCategory? _category;
  late AnalyticsFocus _focus;

  @override
  void initState() {
    super.initState();
    _range = AnalyticsDateRange.current(_period, DateTime.now());
    _focus = widget.focus;
  }

  @override
  void didUpdateWidget(covariant AnalyticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focus != oldWidget.focus) _focus = widget.focus;
  }

  Future<void> _selectPeriod(AnalyticsPeriod period) async {
    if (period != AnalyticsPeriod.custom) {
      setState(() {
        _period = period;
        _range = AnalyticsDateRange.current(period, DateTime.now());
      });
      return;
    }
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(
        start: _range.start,
        end: _range.endInclusive,
      ),
      helpText: 'Choose an analytics date range',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _period = AnalyticsPeriod.custom;
      _range = AnalyticsDateRange.current(
        AnalyticsPeriod.custom,
        now,
        customStart: selected.start,
        customEnd: selected.end,
      );
    });
  }

  Future<void> _refresh() async {
    await widget.controller.load();
    await widget.accountController.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation:
            Listenable.merge([widget.controller, widget.accountController]),
        builder: (context, _) {
          final isLoading =
              widget.controller.isLoading || widget.accountController.isLoading;
          final hasStoredData = widget.controller.expenses.isNotEmpty ||
              widget.accountController.movements
                  .any((movement) => movement.type == 'income');
          if (isLoading && !hasStoredData) {
            return const Center(child: CircularProgressIndicator());
          }
          final analytics = _analytics;
          final hasActivity = analytics.expenses.isNotEmpty ||
              analytics.incomeMovements.isNotEmpty;
          final previous = analytics.previousPeriod(
            allExpenses: widget.controller.expenses,
            allMovements: widget.accountController.movements,
            accounts: widget.accountController.accounts,
          );
          final hasError = widget.controller.error != null ||
              widget.accountController.error != null;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
              children: [
                _PeriodSelector(
                  range: _range,
                  selected: _period,
                  onSelected: _selectPeriod,
                ),
                const SizedBox(height: 14),
                _Filters(
                  accounts: widget.accountController.accounts,
                  accountId: _accountId,
                  category: _category,
                  onAccountChanged: (value) =>
                      setState(() => _accountId = value),
                  onCategoryChanged: (value) =>
                      setState(() => _category = value),
                  onClear: () => setState(() {
                    _accountId = null;
                    _category = null;
                  }),
                ),
                const SizedBox(height: 18),
                if (!hasActivity)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const EmptyState(
                            title: 'No activity in this range',
                            message:
                                'Add an expense or record income to see your spending and cash-flow insights.',
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: widget.onAddExpense,
                            icon: const Icon(Icons.add),
                            label: const Text('Add an expense'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  _SectionTitle(
                    title: 'At a glance',
                    subtitle:
                        '${_formatRange(_range)}  ·  compared with ${_range.comparisonLabel.toLowerCase()}',
                  ),
                  const SizedBox(height: 10),
                  _MetricGrid(
                    analytics: analytics,
                    previous: previous,
                    focus: _focus,
                    onSelected: (focus) => setState(() => _focus = focus),
                  ),
                  const SizedBox(height: 22),
                  _SectionTitle(
                    title: 'Income and spending over time',
                    subtitle:
                        'Income, expenses, and net cash flow by ${_granularityLabel(_range.days)}',
                  ),
                  const SizedBox(height: 10),
                  _TrendCard(points: analytics.trend),
                  const SizedBox(height: 22),
                  const _SectionTitle(
                    title: 'Spending breakdown',
                    subtitle:
                        'Category filters apply to expenses; income remains unchanged.',
                  ),
                  const SizedBox(height: 10),
                  _BreakdownCard(
                    title: 'By category',
                    icon: Icons.category_outlined,
                    entries: analytics.spendingByCategory.entries
                        .map((entry) => _BreakdownEntry(
                              label: entry.key.label,
                              amount: entry.value,
                              icon: entry.key.icon,
                              selected: _category == entry.key,
                              onTap: () => setState(() => _category =
                                  _category == entry.key ? null : entry.key),
                            ))
                        .toList(),
                    total: analytics.expenseTotal,
                    emptyMessage: 'No categorized expenses in this range.',
                  ),
                  const SizedBox(height: 10),
                  _BreakdownCard(
                    title: 'By account',
                    icon: Icons.account_balance_wallet_outlined,
                    entries: analytics.spendingByAccount.entries
                        .map((entry) => _BreakdownEntry(
                              label: entry.key,
                              amount: entry.value,
                              icon: Icons.wallet_outlined,
                              selected: _selectedAccountName == entry.key,
                              onTap: () => _toggleAccountByName(entry.key),
                            ))
                        .toList(),
                    total: analytics.expenseTotal,
                    emptyMessage: 'No account spending in this range.',
                  ),
                  const SizedBox(height: 10),
                  const _UnavailableBreakdownsCard(),
                  const SizedBox(height: 22),
                  const _SectionTitle(
                    title: 'Income analysis',
                    subtitle:
                        'Only recorded income is counted. Transfers and balance adjustments are excluded.',
                  ),
                  const SizedBox(height: 10),
                  _IncomeAnalysisCard(
                    analytics: analytics,
                    previous: previous,
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle(
                    title: 'Transaction insights',
                    subtitle:
                        'Averages include every calendar day in the range.',
                  ),
                  const SizedBox(height: 10),
                  _InsightsCard(
                    analytics: analytics,
                    accounts: widget.accountController.accounts,
                  ),
                  const SizedBox(height: 22),
                  const _PlanningCard(),
                ],
                if (hasError) ...[
                  const SizedBox(height: 14),
                  _ErrorCard(
                    message: [
                      widget.controller.error,
                      widget.accountController.error,
                    ].whereType<String>().join(' '),
                    onRetry: _refresh,
                  ),
                ],
              ],
            ),
          );
        },
      );

  AnalyticsData get _analytics => AnalyticsData(
        expenses: widget.controller.expenses,
        movements: widget.accountController.movements,
        accounts: widget.accountController.accounts,
        range: _range,
        accountId: _accountId,
        category: _category,
      );

  String? get _selectedAccountName {
    for (final account in widget.accountController.accounts) {
      if (account.id == _accountId) return account.name;
    }
    return null;
  }

  void _toggleAccountByName(String name) {
    final account = widget.accountController.accounts
        .where((account) => account.name == name)
        .firstOrNull;
    if (account != null) {
      setState(() => _accountId = _accountId == account.id ? null : account.id);
    }
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.range,
    required this.selected,
    required this.onSelected,
  });

  final AnalyticsDateRange range;
  final AnalyticsPeriod selected;
  final ValueChanged<AnalyticsPeriod> onSelected;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Date range', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AnalyticsPeriod.values.map((period) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(period.label),
                    selected: selected == period,
                    onSelected: (_) => onSelected(period),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            label: 'Selected date range: ${_formatRange(range)}',
            child: Text(
              _formatRange(range),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.accounts,
    required this.accountId,
    required this.category,
    required this.onAccountChanged,
    required this.onCategoryChanged,
    required this.onClear,
  });

  final List<MoneyAccount> accounts;
  final int? accountId;
  final ExpenseCategory? category;
  final ValueChanged<int?> onAccountChanged;
  final ValueChanged<ExpenseCategory?> onCategoryChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilters = accountId != null || category != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child:
                Text('Filters', style: Theme.of(context).textTheme.titleMedium),
          ),
          if (hasFilters)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Clear'),
            ),
        ]),
        const SizedBox(height: 4),
        Text('Account', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('All accounts'),
              selected: accountId == null,
              onSelected: (_) => onAccountChanged(null),
            ),
            ...accounts.map((account) => FilterChip(
                  label: Text(account.name),
                  selected: account.id == accountId,
                  onSelected: (selected) =>
                      onAccountChanged(selected ? account.id : null),
                )),
          ],
        ),
        const SizedBox(height: 8),
        Text('Category', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('All categories'),
              selected: category == null,
              onSelected: (_) => onCategoryChanged(null),
            ),
            ...ExpenseCategory.values.map((value) => FilterChip(
                  label: Text(value.label),
                  selected: category == value,
                  onSelected: (selected) =>
                      onCategoryChanged(selected ? value : null),
                )),
          ],
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.analytics,
    required this.previous,
    required this.focus,
    required this.onSelected,
  });

  final AnalyticsData analytics;
  final AnalyticsData previous;
  final AnalyticsFocus focus;
  final ValueChanged<AnalyticsFocus> onSelected;

  @override
  Widget build(BuildContext context) {
    final rate = analytics.savingsRate;
    final previousRate = previous.savingsRate;
    final rateChange = rate == null || previousRate == null
        ? 'Requires income in both periods'
        : '${_signed((rate - previousRate) * 100, 1)} pp vs previous';
    final tiles = [
      _MetricTileData(
        focus: AnalyticsFocus.income,
        title: 'Income',
        amount: analytics.incomeTotal,
        icon: Icons.south_west,
        change: _percentChange(analytics.incomeTotal, previous.incomeTotal),
      ),
      _MetricTileData(
        focus: AnalyticsFocus.expenses,
        title: 'Expenses',
        amount: analytics.expenseTotal,
        icon: Icons.north_east,
        change: _percentChange(analytics.expenseTotal, previous.expenseTotal),
      ),
      _MetricTileData(
        focus: AnalyticsFocus.cashFlow,
        title: 'Net cash flow',
        amount: analytics.netCashFlow,
        icon: Icons.compare_arrows,
        change:
            '₱${_signed(analytics.netCashFlow - previous.netCashFlow, 2)} vs previous',
      ),
      _MetricTileData(
        focus: AnalyticsFocus.savingsRate,
        title: 'Savings rate',
        amount: rate == null ? null : rate * 100,
        suffix: '%',
        icon: Icons.savings_outlined,
        change: rateChange,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tiles
              .map((tile) => SizedBox(
                    width: width,
                    child: _MetricCard(
                      data: tile,
                      highlighted: focus == tile.focus,
                      onTap: () => onSelected(tile.focus),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _MetricTileData {
  const _MetricTileData({
    required this.focus,
    required this.title,
    required this.amount,
    required this.icon,
    required this.change,
    this.suffix,
  });

  final AnalyticsFocus focus;
  final String title;
  final double? amount;
  final IconData icon;
  final String change;
  final String? suffix;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.data,
    required this.highlighted,
    required this.onTap,
  });

  final _MetricTileData data;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: highlighted
                ? Border.all(color: colors.primary, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(data.icon, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(data.title,
                      style: Theme.of(context).textTheme.labelLarge),
                ),
              ]),
              const SizedBox(height: 10),
              if (data.amount == null)
                Text('—',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold))
              else if (data.suffix != null)
                Text('${data.amount!.toStringAsFixed(1)}${data.suffix}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold))
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(
                    data.amount!,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                data.change,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Card(
          child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('No dated activity to chart in this range.'),
      ));
    }
    final scheme = Theme.of(context).colorScheme;
    final maxAmount = points.fold<double>(
      0,
      (maximum, point) =>
          math.max(maximum, math.max(point.income, point.expenses)),
    );
    final scale = maxAmount == 0 ? 1.0 : maxAmount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _LegendDot(color: scheme.primary, label: 'Income'),
                _LegendDot(color: scheme.error, label: 'Expenses'),
                Text('Net shown below each period',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 164,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: points.map((point) {
                    final label = _trendLabel(point, points.length);
                    return Semantics(
                      button: true,
                      label:
                          '$label. Income ${formatMoney(point.income)}. Expenses ${formatMoney(point.expenses)}. Net cash flow ${formatMoney(point.net)}.',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showTrendDetails(context, point),
                        child: SizedBox(
                          width: points.length > 10 ? 48 : 58,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 100,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _Bar(
                                        height: 100 * point.income / scale,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      _Bar(
                                        height: 100 * point.expenses / scale,
                                        color: scheme.error,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  point.net >= 0
                                      ? '+${formatMoney(point.net)}'
                                      : formatMoney(point.net),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                Text(label,
                                    maxLines: 1,
                                    style:
                                        Theme.of(context).textTheme.labelSmall),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Tap a period for its totals.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: math.max(2, height),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      );
}

class _BreakdownEntry {
  const _BreakdownEntry({
    required this.label,
    required this.amount,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final double amount;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.icon,
    required this.entries,
    required this.total,
    required this.emptyMessage,
  });

  final String title;
  final IconData icon;
  final List<_BreakdownEntry> entries;
  final double total;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final sortedEntries = [...entries]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              MoneyText(total, style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 10),
            if (sortedEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(emptyMessage),
              )
            else
              ...sortedEntries.map((entry) {
                final share = total > 0 ? entry.amount / total : 0.0;
                return Semantics(
                  button: true,
                  selected: entry.selected,
                  label:
                      '${entry.label}: ${formatMoney(entry.amount)}, ${(share * 100).round()} percent. Tap to filter.',
                  child: InkWell(
                    onTap: entry.onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Row(children: [
                            Icon(entry.icon,
                                size: 18,
                                color: entry.selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        fontWeight: entry.selected
                                            ? FontWeight.w600
                                            : null),
                              ),
                            ),
                            MoneyText(entry.amount,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 42,
                              child: Text('${(share * 100).round()}%',
                                  textAlign: TextAlign.end,
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Semantics(
                            label:
                                '${entry.label} share, ${(share * 100).round()} percent',
                            child: LinearProgressIndicator(
                              value: share.clamp(0, 1),
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(4),
                              backgroundColor: scheme.surfaceContainerHighest,
                              color: entry.selected
                                  ? scheme.primary
                                  : scheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            if (sortedEntries.isNotEmpty)
              Text('Tap an item to filter this view.',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _UnavailableBreakdownsCard extends StatelessWidget {
  const _UnavailableBreakdownsCard();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('More breakdowns',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                  'Merchant and payment-method details are not part of expense records yet, so they are not estimated from notes.'),
            ],
          ),
        ),
      );
}

class _IncomeAnalysisCard extends StatelessWidget {
  const _IncomeAnalysisCard({
    required this.analytics,
    required this.previous,
  });

  final AnalyticsData analytics;
  final AnalyticsData previous;

  @override
  Widget build(BuildContext context) {
    final income = analytics.incomeTotal;
    final expenses = analytics.expenseTotal;
    final maxTotal = math.max(income, expenses);
    final incomeAccounts = analytics.incomeByAccount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ComparisonBar(
              label: 'Income',
              amount: income,
              maxAmount: maxTotal,
              color: scheme.primary,
            ),
            const SizedBox(height: 12),
            _ComparisonBar(
              label: 'Expenses',
              amount: expenses,
              maxAmount: maxTotal,
              color: scheme.error,
            ),
            const SizedBox(height: 12),
            Text(
                '${_percentChange(income, previous.incomeTotal)} income · ${_percentChange(expenses, previous.expenseTotal)} expenses vs previous period'),
            const Divider(height: 26),
            Text('Income received by account',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (incomeAccounts.isEmpty)
              const Text('No income recorded in this date range.')
            else
              ...incomeAccounts.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Expanded(child: Text(entry.key)),
                      MoneyText(entry.value,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  )),
          ],
        ),
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.amount,
    required this.maxAmount,
    required this.color,
  });

  final String label;
  final double amount;
  final double maxAmount;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label)),
            MoneyText(amount,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          Semantics(
            label: '$label ${formatMoney(amount)}',
            child: LinearProgressIndicator(
              value: maxAmount > 0 ? amount / maxAmount : 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(6),
              color: color,
            ),
          ),
        ],
      );
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.analytics, required this.accounts});

  final AnalyticsData analytics;
  final List<MoneyAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final largest = analytics.largestExpenses.take(5).toList();
    final largestIncome = analytics.largestIncomeMovements.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.calendar_view_day_outlined),
              const SizedBox(width: 10),
              const Expanded(child: Text('Average spending per day')),
              MoneyText(analytics.averageDailySpending,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text('Across ${analytics.range.days} calendar days',
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 24),
            Text('Largest expenses',
                style: Theme.of(context).textTheme.titleMedium),
            if (largest.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('No expenses to rank in this range.'),
              )
            else
              ...largest.map((expense) => _ExpenseInsightRow(
                    expense: expense,
                    accountName: accounts
                        .where((account) => account.id == expense.accountId)
                        .firstOrNull
                        ?.name,
                  )),
            if (largestIncome.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Largest income',
                  style: Theme.of(context).textTheme.titleSmall),
              ...largestIncome.map((movement) => _IncomeInsightRow(
                    movement: movement,
                    accountName: movement.toName ??
                        accounts
                            .where(
                                (account) => account.id == movement.toAccountId)
                            .firstOrNull
                            ?.name,
                  )),
            ],
            const Divider(height: 24),
            const _InsightNote(
              icon: Icons.repeat,
              message:
                  'Recurring income and expenses are not tracked as recurring items yet.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseInsightRow extends StatelessWidget {
  const _ExpenseInsightRow({
    required this.expense,
    required this.accountName,
  });

  final Expense expense;
  final String? accountName;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label:
            '${expense.category.label} expense ${formatMoney(expense.amount ?? 0)}. Tap for details.',
        child: InkWell(
          onTap: () => _showExpenseDetails(context, expense, accountName),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              Icon(expense.category.icon,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.category.label),
                    Text(
                      '${_formatDate(expense.date)}${accountName == null ? '' : ' · $accountName'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              MoneyText(expense.amount ?? 0,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class _IncomeInsightRow extends StatelessWidget {
  const _IncomeInsightRow({
    required this.movement,
    required this.accountName,
  });

  final AccountMovement movement;
  final String? accountName;

  @override
  Widget build(BuildContext context) => Semantics(
        label:
            'Income ${formatMoney(movement.amount)}${accountName == null ? '' : ' to $accountName'}',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Icon(Icons.south_west,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(accountName ?? 'Income received'),
                  Text(
                    '${_formatDate(movement.date)}${movement.note?.isNotEmpty == true ? ' · ${movement.note}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            MoneyText(movement.amount,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _PlanningCard extends StatelessWidget {
  const _PlanningCard();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Budgets and savings goals',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const _InsightNote(
                icon: Icons.pie_chart_outline,
                message:
                    'Budget and savings-goal tracking is not set up in this app yet. No progress is estimated.',
              ),
            ],
          ),
        ),
      );
}

class _InsightNote extends StatelessWidget {
  const _InsightNote({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ),
            ],
          ),
        ),
      );
}

Future<void> _showTrendDetails(BuildContext context, TrendPoint point) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatBucketRange(point),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _DetailAmount(label: 'Income', amount: point.income),
            _DetailAmount(label: 'Expenses', amount: point.expenses),
            _DetailAmount(label: 'Net cash flow', amount: point.net),
          ],
        ),
      ),
    );

Future<void> _showExpenseDetails(
  BuildContext context,
  Expense expense,
  String? accountName,
) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expense details',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _DetailAmount(label: 'Amount', amount: expense.amount ?? 0),
            _DetailLine(label: 'Category', value: expense.category.label),
            _DetailLine(label: 'Date', value: _formatDate(expense.date)),
            _DetailLine(
                label: 'Account', value: accountName ?? 'Unknown account'),
            if (expense.note?.isNotEmpty == true)
              _DetailLine(label: 'Note', value: expense.note!),
          ],
        ),
      ),
    );

class _DetailAmount extends StatelessWidget {
  const _DetailAmount({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(child: Text(label)),
          MoneyText(amount, style: Theme.of(context).textTheme.titleMedium),
        ]),
      );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

String _percentChange(double current, double previous) {
  if (previous == 0) {
    return current == 0 ? 'No change vs previous' : 'New this period';
  }
  final percent = (current - previous) / previous.abs() * 100;
  return '${percent >= 0 ? '↑' : '↓'} ${percent.abs().toStringAsFixed(1)}% vs previous';
}

String _signed(double amount, int decimals) =>
    '${amount >= 0 ? '+' : '−'}${amount.abs().toStringAsFixed(decimals)}';

String _formatRange(AnalyticsDateRange range) {
  final start = range.start;
  final end = range.endInclusive;
  if (start.year == end.year && start.month == end.month) {
    return '${_monthName(start.month)} ${start.day}–${end.day}, ${end.year}';
  }
  if (start.year == end.year) {
    return '${_monthName(start.month)} ${start.day} – ${_monthName(end.month)} ${end.day}, ${end.year}';
  }
  return '${_monthName(start.month)} ${start.day}, ${start.year} – ${_monthName(end.month)} ${end.day}, ${end.year}';
}

String _formatDate(DateTime? date) => date == null
    ? 'Date not set'
    : '${_monthName(date.month)} ${date.day}, ${date.year}';

String _formatBucketRange(TrendPoint point) {
  final end = point.endExclusive.subtract(const Duration(days: 1));
  if (point.endExclusive.difference(point.start).inDays <= 1) {
    return _formatDate(point.start);
  }
  if (point.start.year == end.year && point.start.month == end.month) {
    return '${_monthName(point.start.month)} ${point.start.day}–${end.day}, ${end.year}';
  }
  return '${_monthName(point.start.month)} ${point.start.day} – ${_monthName(end.month)} ${end.day}, ${end.year}';
}

String _trendLabel(TrendPoint point, int count) {
  if (count > 120 || point.endExclusive.month != point.start.month) {
    return _monthName(point.start.month).substring(0, 3);
  }
  if (point.endExclusive.difference(point.start).inDays > 1) {
    return '${point.start.month}/${point.start.day}';
  }
  return '${point.start.day}';
}

String _granularityLabel(int days) => days <= 31
    ? 'day'
    : days <= 120
        ? 'week'
        : 'month';

String _monthName(int month) => const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][month - 1];
