import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.title,
      required this.message,
      this.icon = Icons.receipt_long_outlined});
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
}
