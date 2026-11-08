class AccountMovement {
  const AccountMovement(
      {required this.id,
      required this.type,
      required this.amount,
      required this.date,
      this.fromAccountId,
      this.toAccountId,
      this.fromName,
      this.toName,
      this.note});

  final int id;
  final String type;
  final double amount;
  final DateTime date;
  final int? fromAccountId;
  final int? toAccountId;
  final String? fromName;
  final String? toName;
  final String? note;
}
