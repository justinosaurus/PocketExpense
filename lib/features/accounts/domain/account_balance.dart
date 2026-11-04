class AccountBalance {
  static double calculate(
          {required double expenses,
          required double incoming,
          required double outgoing}) =>
      incoming - outgoing - expenses;
}
