class CashShift {
  final int? id;
  final String shiftNumber;
  final int cashierId;
  final String? cashierName;
  final double openingBalance;
  final double closingBalanceSystem;
  final double closingBalancePhysical;
  final double difference;
  final String? closingNote;
  final String openedAt;
  final String? closedAt;
  final String status; // 'OPEN' or 'CLOSED'
  final double totalCashSales;
  final double totalNonCashSales;
  final double totalSales;
  final int transactionCount;
  final double totalCashIn;
  final double totalCashOut;
  final double expectedCash;

  const CashShift({
    this.id,
    required this.shiftNumber,
    required this.cashierId,
    this.cashierName,
    this.openingBalance = 0.0,
    this.closingBalanceSystem = 0.0,
    this.closingBalancePhysical = 0.0,
    this.difference = 0.0,
    this.closingNote,
    required this.openedAt,
    this.closedAt,
    this.status = 'OPEN',
    this.totalCashSales = 0.0,
    this.totalNonCashSales = 0.0,
    this.totalSales = 0.0,
    this.transactionCount = 0,
    this.totalCashIn = 0.0,
    this.totalCashOut = 0.0,
    this.expectedCash = 0.0,
  });

  bool get isOpen => status.toUpperCase() == 'OPEN';
  bool get isClosed => status.toUpperCase() == 'CLOSED';

  factory CashShift.fromMap(Map<String, dynamic> map) {
    final opening = (map['opening_balance'] as num?)?.toDouble() ?? 0.0;
    final sysClose = (map['closing_balance_system'] as num?)?.toDouble() ?? 0.0;
    final physClose = (map['closing_balance_physical'] as num?)?.toDouble() ?? 0.0;
    final diff = (map['difference'] as num?)?.toDouble() ?? 0.0;
    final cashSales = (map['total_cash_sales'] as num?)?.toDouble() ??
        (map['sales_total'] as num?)?.toDouble() ?? 0.0;
    final nonCashSales = (map['total_non_cash_sales'] as num?)?.toDouble() ?? 0.0;
    final allSales = (map['total_sales'] as num?)?.toDouble() ?? (cashSales + nonCashSales);
    final txCount = (map['transaction_count'] as num?)?.toInt() ?? 0;
    final cIn = (map['movements_in'] as num?)?.toDouble() ??
        (map['total_cash_in'] as num?)?.toDouble() ?? 0.0;
    final cOut = (map['movements_out'] as num?)?.toDouble() ??
        (map['total_cash_out'] as num?)?.toDouble() ?? 0.0;
    final exp = (map['expected_cash'] as num?)?.toDouble() ?? (opening + cashSales + cIn - cOut);

    return CashShift(
      id: map['id'] as int?,
      shiftNumber: (map['shift_number'] as String?) ??
          'SHF-${(map['id'] ?? 1).toString().padLeft(4, '0')}',
      cashierId: (map['cashier_id'] as num?)?.toInt() ?? 1,
      cashierName: (map['cashier_name'] as String?) ?? (map['cashier'] as String?),
      openingBalance: opening,
      closingBalanceSystem: sysClose,
      closingBalancePhysical: physClose,
      difference: diff,
      closingNote: map['closing_note'] as String?,
      openedAt: (map['opened_at'] as String?) ?? DateTime.now().toIso8601String(),
      closedAt: map['closed_at'] as String?,
      status: (map['status'] as String?) ?? 'OPEN',
      totalCashSales: cashSales,
      totalNonCashSales: nonCashSales,
      totalSales: allSales,
      transactionCount: txCount,
      totalCashIn: cIn,
      totalCashOut: cOut,
      expectedCash: exp,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'shift_number': shiftNumber,
      'cashier_id': cashierId,
      'opening_balance': openingBalance,
      'closing_balance_system': closingBalanceSystem,
      'closing_balance_physical': closingBalancePhysical,
      'difference': difference,
      'closing_note': closingNote,
      'opened_at': openedAt,
      'closed_at': closedAt,
      'status': status,
    };
    if (id != null) map['id'] = id;
    return map;
  }
}

class ShiftMovement {
  final int? id;
  final int shiftId;
  final String type; // 'IN' or 'OUT'
  final double amount;
  final String reason;
  final int createdBy;
  final String? createdByName;
  final String createdAt;

  const ShiftMovement({
    this.id,
    required this.shiftId,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
  });

  bool get isCashIn => type.toUpperCase() == 'IN';
  bool get isCashOut => type.toUpperCase() == 'OUT';

  factory ShiftMovement.fromMap(Map<String, dynamic> map) {
    return ShiftMovement(
      id: map['id'] as int?,
      shiftId: (map['shift_id'] as num?)?.toInt() ?? 0,
      type: (map['type'] as String?) ?? 'IN',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      reason: (map['reason'] as String?) ?? '',
      createdBy: (map['created_by'] as num?)?.toInt() ?? 1,
      createdByName: (map['created_by_name'] as String?) ?? (map['cashier'] as String?),
      createdAt: (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'shift_id': shiftId,
      'type': type,
      'amount': amount,
      'reason': reason,
      'created_by': createdBy,
      'created_at': createdAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }
}
