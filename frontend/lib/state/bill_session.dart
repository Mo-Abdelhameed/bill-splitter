import 'package:flutter/foundation.dart';

import '../logic/totals.dart';
import '../models/models.dart';

/// Holds the in-session bill state: extracted receipt, diners, and
/// item → diner assignments. Survives navigation between screens.
class BillSession extends ChangeNotifier {
  ExtractedReceipt? _receipt;
  ReceiptCharges _charges = const ReceiptCharges();
  final List<Diner> _diners = [];
  final AssignmentMap _assignments = {};

  ExtractedReceipt? get receipt => _receipt;
  ReceiptCharges get charges => _charges;
  List<Diner> get diners => List.unmodifiable(_diners);
  AssignmentMap get assignments => Map.unmodifiable(
        _assignments.map((k, v) => MapEntry(k, Set<String>.unmodifiable(v))),
      );

  void setReceipt(ExtractedReceipt receipt) {
    _receipt = receipt;
    _charges = receipt.charges;
    _assignments.clear();
    notifyListeners();
  }

  void clear() {
    _receipt = null;
    _charges = const ReceiptCharges();
    _diners.clear();
    _assignments.clear();
    notifyListeners();
  }

  Diner addDiner(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Diner name must not be empty');
    }
    final id = 'd_${DateTime.now().microsecondsSinceEpoch}_${_diners.length}';
    final diner = Diner(id: id, name: trimmed);
    _diners.add(diner);
    notifyListeners();
    return diner;
  }

  void renameDiner(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final idx = _diners.indexWhere((d) => d.id == id);
    if (idx < 0) return;
    _diners[idx] = _diners[idx].copyWith(name: trimmed);
    notifyListeners();
  }

  void removeDiner(String id) {
    _diners.removeWhere((d) => d.id == id);
    for (final entry in _assignments.entries.toList()) {
      entry.value.remove(id);
    }
    notifyListeners();
  }

  void toggleAssignment(String itemId, String dinerId) {
    final set = _assignments.putIfAbsent(itemId, () => <String>{});
    if (!set.add(dinerId)) {
      set.remove(dinerId);
    }
    notifyListeners();
  }

  bool isAssigned(String itemId, String dinerId) {
    return _assignments[itemId]?.contains(dinerId) ?? false;
  }

  void setTaxOverride(double? value) {
    _charges = _charges.copyWith(tax: value, clearTax: value == null);
    notifyListeners();
  }

  void setServiceOverride(double? value) {
    _charges = _charges.copyWith(service: value, clearService: value == null);
    notifyListeners();
  }

  List<ReceiptItem> get items => _receipt?.items ?? const [];

  List<ReceiptItem> get unassigned =>
      unassignedItems(items, _assignments);

  BillTotals computeTotals() {
    return computeTotalsFromArgs(
      diners: _diners,
      items: items,
      assignments: _assignments,
      charges: _charges,
    );
  }
}

// Indirection so we can swap impl in tests if ever needed.
BillTotals computeTotalsFromArgs({
  required List<Diner> diners,
  required List<ReceiptItem> items,
  required AssignmentMap assignments,
  required ReceiptCharges charges,
}) {
  return computeTotals(
    diners: diners,
    items: items,
    assignments: assignments,
    charges: charges,
  );
}
