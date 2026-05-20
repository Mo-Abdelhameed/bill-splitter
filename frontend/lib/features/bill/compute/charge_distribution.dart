/// Distribute a bill-level charge (tax or service) across people in
/// proportion to each person's item subtotal — FR-012.
///
/// - `charge == null` → no distribution (FR-013); returns empty map.
/// - `charge == 0`    → every person gets 0.
/// - sum of subtotals == 0 → no proportional anchor; returns empty.
Map<String, num> distributeCharge({
  required num? charge,
  required Map<String, num> itemSubtotals,
}) {
  if (charge == null) return const {};

  if (charge == 0) {
    return {for (final id in itemSubtotals.keys) id: 0};
  }

  final total = itemSubtotals.values.fold<num>(0, (a, b) => a + b);
  if (total == 0) return const {};

  return {
    for (final entry in itemSubtotals.entries)
      entry.key: charge * (entry.value / total),
  };
}
