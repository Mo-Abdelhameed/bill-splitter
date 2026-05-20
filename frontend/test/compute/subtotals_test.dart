import 'package:bill_splitter/features/bill/compute/subtotals.dart';
import 'package:bill_splitter/features/bill/model/assignment.dart';
import 'package:bill_splitter/features/bill/model/item.dart';
import 'package:flutter_test/flutter_test.dart';

Item _item(String id, String name, num price, {int qty = 1}) => Item(
      id: id,
      name: name,
      quantity: qty,
      unitPrice: price,
      source: ItemSource.manual,
    );

void main() {
  test('FR-011: solo assignment puts full line total on the assignee', () {
    final items = [_item('i1', 'Koshary', 60, qty: 2)]; // line total 120
    final assignments = {
      'i1': Assignment(itemId: 'i1', personIds: {'A'}),
    };

    final out = computeItemSubtotals(
      personIds: ['A', 'B'],
      items: items,
      assignments: assignments,
    );

    expect(out['A'], 120);
    expect(out['B'], 0);
  });

  test('FR-008 + FR-009: shared item with default equal split divides evenly', () {
    final items = [_item('i1', 'Hummus', 90)];
    final assignments = {
      'i1': Assignment(itemId: 'i1', personIds: {'A', 'B', 'C'}),
    };

    final out = computeItemSubtotals(
      personIds: ['A', 'B', 'C'],
      items: items,
      assignments: assignments,
    );

    expect(out['A'], 30);
    expect(out['B'], 30);
    expect(out['C'], 30);
  });

  test('FR-009: per-item weight override redistributes that item only', () {
    final items = [
      _item('i1', 'Steak', 100),
      _item('i2', 'Soda', 30),
    ];
    final assignments = {
      'i1': Assignment(
        itemId: 'i1',
        personIds: {'A', 'B'},
        weights: {'A': 3, 'B': 1},
      ),
      'i2': Assignment(itemId: 'i2', personIds: {'A', 'B'}),
    };

    final out = computeItemSubtotals(
      personIds: ['A', 'B'],
      items: items,
      assignments: assignments,
    );

    // Steak: A 3/4 = 75, B 1/4 = 25. Soda: equal split 15 each.
    expect(out['A'], 75 + 15);
    expect(out['B'], 25 + 15);
  });

  test('FR-008: M:N — same person on many items, same item on many people', () {
    final items = [
      _item('i1', 'A', 50),
      _item('i2', 'B', 80),
      _item('i3', 'C', 30),
    ];
    final assignments = {
      'i1': Assignment(itemId: 'i1', personIds: {'P1', 'P2'}),     // 25 + 25
      'i2': Assignment(itemId: 'i2', personIds: {'P1'}),           // 80 on P1
      'i3': Assignment(itemId: 'i3', personIds: {'P2', 'P3'}),     // 15 + 15
    };

    final out = computeItemSubtotals(
      personIds: ['P1', 'P2', 'P3'],
      items: items,
      assignments: assignments,
    );

    expect(out['P1'], 25 + 80);
    expect(out['P2'], 25 + 15);
    expect(out['P3'], 15);
  });

  test('FR-011: an item with no assignment contributes 0 to everyone', () {
    final items = [_item('i1', 'Lonely', 50)];
    final out = computeItemSubtotals(
      personIds: ['A', 'B'],
      items: items,
      assignments: const {},
    );
    expect(out['A'], 0);
    expect(out['B'], 0);
  });
}
