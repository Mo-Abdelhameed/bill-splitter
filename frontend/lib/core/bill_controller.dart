import 'package:flutter/foundation.dart';

import '../features/bill/data/extract_repository.dart';
import '../features/bill/model/assignment.dart';
import '../features/bill/model/item.dart';
import '../features/bill/model/person.dart';

/// Ephemeral bill state held in memory only (FR-018: no persistence).
class BillController extends ChangeNotifier {
  List<Person> _people = const [];
  List<Item> _items = const [];
  num? _taxAmount;
  num? _serviceAmount;
  Map<String, Assignment> _assignments = const {};

  List<Person> get people => _people;
  List<Item> get items => _items;
  num? get taxAmount => _taxAmount;
  num? get serviceAmount => _serviceAmount;
  Map<String, Assignment> get assignments => _assignments;

  void setPeople(List<Person> people) {
    _people = List.unmodifiable(people);
    notifyListeners();
  }

  void setExtractResult(ExtractResult result) {
    _items = List.unmodifiable(result.items);
    _taxAmount = result.taxAmount;
    _serviceAmount = result.serviceAmount;
    _assignments = const {};
    notifyListeners();
  }

  void setAssignments(Map<String, Assignment> assignments) {
    _assignments = Map.unmodifiable(assignments);
    notifyListeners();
  }

  /// Replaces items + tax/service post-edit on the items screen (US5).
  void setItemsAndCharges({
    required List<Item> items,
    required num? taxAmount,
    required num? serviceAmount,
  }) {
    _items = List.unmodifiable(items);
    _taxAmount = taxAmount;
    _serviceAmount = serviceAmount;
    _assignments = const {};
    notifyListeners();
  }

  /// FR-017 / FR-018: reset bill state when starting a new bill.
  void reset() {
    _people = const [];
    _items = const [];
    _taxAmount = null;
    _serviceAmount = null;
    _assignments = const {};
    notifyListeners();
  }
}
