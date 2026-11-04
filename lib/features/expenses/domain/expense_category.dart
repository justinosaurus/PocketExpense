import 'package:flutter/material.dart';

enum ExpenseCategory {
  food,
  transport,
  shopping,
  bills,
  health,
  entertainment,
  other
}

extension ExpenseCategoryDetails on ExpenseCategory {
  String get label => switch (this) {
        ExpenseCategory.food => 'Food',
        ExpenseCategory.transport => 'Transport',
        ExpenseCategory.shopping => 'Shopping',
        ExpenseCategory.bills => 'Bills',
        ExpenseCategory.health => 'Health',
        ExpenseCategory.entertainment => 'Entertainment',
        ExpenseCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        ExpenseCategory.food => Icons.restaurant,
        ExpenseCategory.transport => Icons.directions_bus,
        ExpenseCategory.shopping => Icons.shopping_bag,
        ExpenseCategory.bills => Icons.receipt,
        ExpenseCategory.health => Icons.health_and_safety,
        ExpenseCategory.entertainment => Icons.movie,
        ExpenseCategory.other => Icons.category,
      };

  static ExpenseCategory fromStorage(String value) =>
      ExpenseCategory.values.firstWhere(
        (category) => category.name == value,
        orElse: () => ExpenseCategory.other,
      );
}
