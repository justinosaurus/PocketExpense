import 'package:flutter/material.dart';

String formatMoney(double amount) => '₱${amount.toStringAsFixed(2)}';

class MoneyText extends StatelessWidget {
  const MoneyText(this.amount, {super.key, this.style});
  final double amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(formatMoney(amount), style: style);
}
