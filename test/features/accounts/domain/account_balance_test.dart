import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_expenses/features/accounts/domain/account_balance.dart';

void main() {
  test(
      'expenses reduce balance while transfers and adjustments affect the right account net',
      () {
    expect(
        AccountBalance.calculate(expenses: 650, incoming: 300, outgoing: 125),
        -475);
  });

  test('a transfer nets to zero across all accounts', () {
    final source =
        AccountBalance.calculate(expenses: 0, incoming: 0, outgoing: 200);
    final destination =
        AccountBalance.calculate(expenses: 0, incoming: 200, outgoing: 0);
    expect(source + destination, 0);
  });
}
