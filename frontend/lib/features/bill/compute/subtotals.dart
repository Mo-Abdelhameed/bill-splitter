import '../model/assignment.dart';
import '../model/item.dart';

/// Per-person item subtotals: for each item assigned to a person, add their
/// share of the line total (equal-split default, or weighted when overridden).
///
/// `assignments` is keyed by `Item.id`. People not assigned to any item end up
/// with 0.
Map<String, num> computeItemSubtotals({
  required List<String> personIds,
  required List<Item> items,
  required Map<String, Assignment> assignments,
}) {
  final result = <String, num>{for (final id in personIds) id: 0};

  for (final item in items) {
    final a = assignments[item.id];
    if (a == null || a.personIds.isEmpty) continue;

    final lineTotal = item.lineTotal;
    if (a.weights == null) {
      // Equal split.
      final share = lineTotal / a.personIds.length;
      for (final pid in a.personIds) {
        result[pid] = (result[pid] ?? 0) + share;
      }
    } else {
      final weights = a.weights!;
      final totalWeight = weights.values.fold<num>(0, (s, w) => s + w);
      for (final pid in a.personIds) {
        final w = weights[pid] ?? 0;
        result[pid] = (result[pid] ?? 0) + lineTotal * (w / totalWeight);
      }
    }
  }

  return result;
}
