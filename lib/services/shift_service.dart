import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/shift.dart';

class ShiftService {
  static final ShiftService instance = ShiftService._internal();
  factory ShiftService() => instance;
  ShiftService._internal();

  final ValueNotifier<CashShift?> activeShiftNotifier = ValueNotifier<CashShift?>(null);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);

  CashShift? get currentShift => activeShiftNotifier.value;
  bool get hasActiveShift => activeShiftNotifier.value != null;

  Future<CashShift?> refreshActiveShift() async {
    try {
      isLoadingNotifier.value = true;
      final summary = await DatabaseHelper.instance.getActiveShiftSummary();
      if (summary != null) {
        final shift = CashShift.fromMap(summary);
        activeShiftNotifier.value = shift;
        return shift;
      } else {
        activeShiftNotifier.value = null;
        return null;
      }
    } catch (e) {
      debugPrint('Error refreshing active shift: $e');
      activeShiftNotifier.value = null;
      return null;
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  Future<CashShift> openShift({
    required int cashierId,
    required double openingBalance,
  }) async {
    isLoadingNotifier.value = true;
    try {
      await DatabaseHelper.instance.openShift(
        cashierId: cashierId,
        openingBalance: openingBalance,
      );
      final shift = await refreshActiveShift();
      if (shift == null) {
        throw Exception('Gagal memuat shift setelah dibuka.');
      }
      return shift;
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  Future<void> closeShift({
    required int shiftId,
    required double physicalBalance,
    String? note,
    int? closedBy,
  }) async {
    isLoadingNotifier.value = true;
    try {
      await DatabaseHelper.instance.closeShift(
        shiftId: shiftId,
        physicalBalance: physicalBalance,
        note: note,
        closedBy: closedBy,
      );
      await refreshActiveShift();
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  Future<void> addCashMovement({
    required int shiftId,
    required String type,
    required double amount,
    required String reason,
    required int userId,
  }) async {
    await DatabaseHelper.instance.addCashMovement(
      shiftId,
      type,
      amount,
      reason,
      userId: userId,
    );
    await refreshActiveShift();
  }

  Future<List<CashShift>> getShiftHistory({
    String? startDate,
    String? endDate,
    int? cashierId,
    String? status,
    String? searchQuery,
    int limit = 100,
  }) async {
    final list = await DatabaseHelper.instance.getShiftHistory(
      startDate: startDate,
      endDate: endDate,
      cashierId: cashierId,
      status: status,
      searchQuery: searchQuery,
      limit: limit,
    );
    return list.map((m) => CashShift.fromMap(m)).toList();
  }

  Future<Map<String, dynamic>?> getShiftDetails(int shiftId) async {
    return await DatabaseHelper.instance.getShiftDetails(shiftId);
  }
}
