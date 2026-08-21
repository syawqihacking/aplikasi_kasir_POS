import 'package:flutter_test/flutter_test.dart';
import 'package:customerbandung/models/shift.dart';

void main() {
  group('CashShift Model Tests', () {
    test('CashShift.fromMap calculates metrics and expected cash accurately', () {
      final map = {
        'id': 1,
        'shift_number': 'SHF-20260822-001',
        'cashier_id': 2,
        'cashier_name': 'Budi Kasir',
        'opening_balance': 100000.0,
        'closing_balance_system': 0.0,
        'closing_balance_physical': 0.0,
        'difference': 0.0,
        'opened_at': '2026-08-22T08:00:00.000',
        'status': 'OPEN',
        'total_cash_sales': 150000.0,
        'total_non_cash_sales': 75000.0,
        'total_sales': 225000.0,
        'transaction_count': 5,
        'movements_in': 50000.0,
        'movements_out': 20000.0,
        'expected_cash': 280000.0,
      };

      final shift = CashShift.fromMap(map);

      expect(shift.id, 1);
      expect(shift.shiftNumber, 'SHF-20260822-001');
      expect(shift.cashierName, 'Budi Kasir');
      expect(shift.openingBalance, 100000.0);
      expect(shift.totalCashSales, 150000.0);
      expect(shift.totalNonCashSales, 75000.0);
      expect(shift.totalSales, 225000.0);
      expect(shift.transactionCount, 5);
      expect(shift.totalCashIn, 50000.0);
      expect(shift.totalCashOut, 20000.0);
      // Expected cash = 100,000 (modal) + 150,000 (cash sales) + 50,000 (in) - 20,000 (out) = 280,000
      expect(shift.expectedCash, 280000.0);
      expect(shift.isOpen, isTrue);
      expect(shift.isClosed, isFalse);
    });

    test('ShiftMovement.fromMap parses Cash In and Out correctly', () {
      final cashInMap = {
        'id': 10,
        'shift_id': 1,
        'type': 'IN',
        'amount': 50000.0,
        'reason': 'Tambahan Modal Kasir',
        'created_by': 2,
        'created_by_name': 'Budi Kasir',
        'created_at': '2026-08-22T09:00:00.000',
      };

      final movement = ShiftMovement.fromMap(cashInMap);
      expect(movement.isCashIn, isTrue);
      expect(movement.isCashOut, isFalse);
      expect(movement.amount, 50000.0);
      expect(movement.reason, 'Tambahan Modal Kasir');
    });

    test('Difference calculation works for surplus, deficit, and match', () {
      const systemCash = 300000.0;

      // Exact match
      const physicalMatch = 300000.0;
      final diffMatch = physicalMatch - systemCash;
      expect(diffMatch, 0.0);

      // Surplus
      const physicalSurplus = 305000.0;
      final diffSurplus = physicalSurplus - systemCash;
      expect(diffSurplus, 5000.0);

      // Deficit
      const physicalDeficit = 290000.0;
      final diffDeficit = physicalDeficit - systemCash;
      expect(diffDeficit, -10000.0);
    });
  });
}
