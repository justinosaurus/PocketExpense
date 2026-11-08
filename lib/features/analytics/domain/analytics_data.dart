import '../../accounts/domain/account_movement.dart';
import '../../accounts/domain/money_account.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_category.dart';

enum AnalyticsPeriod { week, month, quarter, year, custom }

extension AnalyticsPeriodLabel on AnalyticsPeriod {
  String get label => switch (this) {
        AnalyticsPeriod.week => 'This week',
        AnalyticsPeriod.month => 'This month',
        AnalyticsPeriod.quarter => 'This quarter',
        AnalyticsPeriod.year => 'This year',
        AnalyticsPeriod.custom => 'Custom',
      };
}

class AnalyticsDateRange {
  const AnalyticsDateRange({
    required this.start,
    required this.endExclusive,
    required this.period,
  });

  factory AnalyticsDateRange.current(
    AnalyticsPeriod period,
    DateTime now, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final today = _dateOnly(now);
    final start = switch (period) {
      AnalyticsPeriod.week => today.subtract(Duration(days: today.weekday - 1)),
      AnalyticsPeriod.month => DateTime(today.year, today.month),
      AnalyticsPeriod.quarter =>
        DateTime(today.year, ((today.month - 1) ~/ 3) * 3 + 1),
      AnalyticsPeriod.year => DateTime(today.year),
      AnalyticsPeriod.custom => _dateOnly(customStart ?? today),
    };
    final end = period == AnalyticsPeriod.custom
        ? _dateOnly(customEnd ?? today)
        : today;
    return AnalyticsDateRange(
      start: start.isAfter(end) ? end : start,
      endExclusive:
          (start.isAfter(end) ? start : end).add(const Duration(days: 1)),
      period: period,
    );
  }

  final DateTime start;
  final DateTime endExclusive;
  final AnalyticsPeriod period;

  int get days => endExclusive.difference(start).inDays;
  DateTime get endInclusive => endExclusive.subtract(const Duration(days: 1));

  AnalyticsDateRange get previous => AnalyticsDateRange(
        start: start.subtract(Duration(days: days)),
        endExclusive: start,
        period: period,
      );

  bool contains(DateTime? date) {
    if (date == null) return false;
    final day = _dateOnly(date);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  String get comparisonLabel => 'Previous $days ${days == 1 ? 'day' : 'days'}';

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

enum TrendGranularity { day, week, month }

class TrendPoint {
  const TrendPoint({
    required this.start,
    required this.endExclusive,
    required this.income,
    required this.expenses,
  });

  final DateTime start;
  final DateTime endExclusive;
  final double income;
  final double expenses;
  double get net => income - expenses;
}

class AnalyticsData {
  AnalyticsData({
    required Iterable<Expense> expenses,
    required Iterable<AccountMovement> movements,
    required Iterable<MoneyAccount> accounts,
    required this.range,
    int? accountId,
    ExpenseCategory? category,
  })  : accountId = accountId,
        category = category,
        _accountsById = {for (final account in accounts) account.id: account},
        expenses = _filterExpenses(
          expenses,
          range,
          accountId,
          category,
        ),
        incomeMovements = _filterIncome(
          movements,
          range,
          accountId,
        );

  final AnalyticsDateRange range;
  final int? accountId;
  final ExpenseCategory? category;
  final List<Expense> expenses;
  final List<AccountMovement> incomeMovements;
  final Map<int, MoneyAccount> _accountsById;

  double get expenseTotal => expenses.fold<double>(
      0, (total, expense) => total + _validAmount(expense.amount));
  double get incomeTotal => incomeMovements.fold<double>(
      0, (total, movement) => total + _validAmount(movement.amount));
  double get netCashFlow => incomeTotal - expenseTotal;
  double? get savingsRate => incomeTotal > 0 ? netCashFlow / incomeTotal : null;
  double get averageDailySpending => expenseTotal / range.days;

  Map<ExpenseCategory, double> get spendingByCategory {
    final totals = <ExpenseCategory, double>{};
    for (final expense in expenses) {
      totals.update(
          expense.category, (value) => value + _validAmount(expense.amount),
          ifAbsent: () => _validAmount(expense.amount));
    }
    return totals;
  }

  Map<String, double> get spendingByAccount {
    final totals = <String, double>{};
    for (final expense in expenses) {
      final name = _accountsById[expense.accountId]?.name ?? 'Unknown account';
      totals.update(name, (value) => value + _validAmount(expense.amount),
          ifAbsent: () => _validAmount(expense.amount));
    }
    return totals;
  }

  Map<String, double> get incomeByAccount {
    final totals = <String, double>{};
    for (final movement in incomeMovements) {
      final name = movement.toName ??
          (movement.toAccountId == null
              ? 'Unknown account'
              : _accountsById[movement.toAccountId]?.name ?? 'Unknown account');
      totals.update(name, (value) => value + movement.amount,
          ifAbsent: () => movement.amount);
    }
    return totals;
  }

  List<Expense> get largestExpenses {
    final result = [
      ...expenses
    ]..sort((a, b) => _validAmount(b.amount).compareTo(_validAmount(a.amount)));
    return result;
  }

  List<AccountMovement> get largestIncomeMovements {
    final result = [...incomeMovements]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  List<TrendPoint> get trend {
    final granularity = range.days <= 31
        ? TrendGranularity.day
        : range.days <= 120
            ? TrendGranularity.week
            : TrendGranularity.month;
    final points = <TrendPoint>[];
    var cursor = _bucketStart(range.start, granularity);
    while (cursor.isBefore(range.endExclusive)) {
      final next = _nextBucket(cursor, granularity);
      final expensesInBucket = expenses.where((expense) {
        final date = expense.date;
        if (date == null) return false;
        final day = DateTime(date.year, date.month, date.day);
        return !day.isBefore(cursor) && day.isBefore(next);
      });
      final incomeInBucket = incomeMovements.where((movement) {
        final day = DateTime(
            movement.date.year, movement.date.month, movement.date.day);
        return !day.isBefore(cursor) && day.isBefore(next);
      });
      points.add(TrendPoint(
        start: cursor,
        endExclusive: next,
        income: incomeInBucket.fold<double>(
            0, (sum, movement) => sum + movement.amount),
        expenses: expensesInBucket.fold<double>(
            0, (sum, expense) => sum + _validAmount(expense.amount)),
      ));
      cursor = next;
    }
    return points;
  }

  AnalyticsData previousPeriod({
    required Iterable<Expense> allExpenses,
    required Iterable<AccountMovement> allMovements,
    required Iterable<MoneyAccount> accounts,
  }) =>
      AnalyticsData(
        expenses: allExpenses,
        movements: allMovements,
        accounts: accounts,
        range: range.previous,
        accountId: accountId,
        category: category,
      );

  static List<Expense> _filterExpenses(
    Iterable<Expense> expenses,
    AnalyticsDateRange range,
    int? accountId,
    ExpenseCategory? category,
  ) =>
      expenses.where((expense) {
        final amount = expense.amount;
        return amount != null &&
            amount.isFinite &&
            amount >= 0 &&
            range.contains(expense.date) &&
            (accountId == null || expense.accountId == accountId) &&
            (category == null || expense.category == category);
      }).toList();

  static List<AccountMovement> _filterIncome(
    Iterable<AccountMovement> movements,
    AnalyticsDateRange range,
    int? accountId,
  ) =>
      movements.where((movement) {
        return movement.type == 'income' &&
            movement.amount.isFinite &&
            movement.amount > 0 &&
            range.contains(movement.date) &&
            (accountId == null || movement.toAccountId == accountId);
      }).toList();

  static double _validAmount(double? amount) =>
      amount != null && amount.isFinite && amount >= 0 ? amount : 0;

  static DateTime _bucketStart(DateTime date, TrendGranularity granularity) =>
      switch (granularity) {
        TrendGranularity.day => DateTime(date.year, date.month, date.day),
        TrendGranularity.week =>
          DateTime(date.year, date.month, date.day - date.weekday + 1),
        TrendGranularity.month => DateTime(date.year, date.month),
      };

  static DateTime _nextBucket(DateTime date, TrendGranularity granularity) =>
      switch (granularity) {
        TrendGranularity.day => date.add(const Duration(days: 1)),
        TrendGranularity.week => date.add(const Duration(days: 7)),
        TrendGranularity.month => DateTime(date.year, date.month + 1),
      };
}
