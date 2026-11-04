class AccountMovement {
  const AccountMovement(
      {required this.id,
      required this.type,
      required this.amount,
      required this.date,
      this.fromName,
      this.toName,
      this.note});

  final int id;
  final String type;
  final double amount;
  final DateTime date;
  final String? fromName;
  final String? toName;
  final String? note;
}
