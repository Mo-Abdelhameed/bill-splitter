import '../models/models.dart';

/// Per-item assignment: item id -> set of diner ids.
typedef AssignmentMap = Map<String, Set<String>>;

int _toCents(double value) {
  // Round half-to-even on the smallest sub-cent fraction to avoid float drift.
  final scaled = value * 100;
  return _roundHalfToEven(scaled);
}

int _roundHalfToEven(double v) {
  final floor = v.floorToDouble();
  final diff = v - floor;
  if (diff < 0.5) return floor.toInt();
  if (diff > 0.5) return (floor + 1).toInt();
  // Exactly .5 — round to even.
  final f = floor.toInt();
  return f.isEven ? f : f + 1;
}

/// Computes per-diner totals from item assignments and detected charges.
///
/// Allocation rules:
///   - Each item's cost is split equally among its assigned diners.
///   - Tax and service are each allocated proportionally to each diner's
///     pre-tax subtotal (relative to the sum of all diner subtotals).
///   - All arithmetic is done in integer cents to avoid float drift.
///   - Per-diner totals use banker's rounding; the residual against the bill
///     grand total is surfaced separately so the UI can disclose it.
BillTotals computeTotals({
  required List<Diner> diners,
  required List<ReceiptItem> items,
  required AssignmentMap assignments,
  required ReceiptCharges charges,
}) {
  // 1. Subtotal per diner, in cents.
  final subtotals = {for (final d in diners) d.id: 0};
  for (final item in items) {
    final assignees = assignments[item.id] ?? const <String>{};
    if (assignees.isEmpty) continue;
    final itemCents = _toCents(item.price);
    final share = itemCents ~/ assignees.length;
    final remainder = itemCents - share * assignees.length;
    // Distribute the remainder cent-by-cent across assignees in a stable order
    // so totals are deterministic.
    final ordered = assignees.toList()..sort();
    for (var i = 0; i < ordered.length; i++) {
      final extra = i < remainder ? 1 : 0;
      subtotals[ordered[i]] = (subtotals[ordered[i]] ?? 0) + share + extra;
    }
  }

  final totalSubtotalCents = subtotals.values.fold<int>(0, (a, b) => a + b);
  final taxCents = charges.tax == null ? 0 : _toCents(charges.tax!);
  final serviceCents = charges.service == null ? 0 : _toCents(charges.service!);

  // 2. Proportional tax/service per diner.
  final taxShares = <String, int>{for (final d in diners) d.id: 0};
  final serviceShares = <String, int>{for (final d in diners) d.id: 0};

  if (totalSubtotalCents > 0) {
    _allocateProportional(
      totalCents: taxCents,
      subtotals: subtotals,
      out: taxShares,
    );
    _allocateProportional(
      totalCents: serviceCents,
      subtotals: subtotals,
      out: serviceShares,
    );
  }

  final perDiner = <DinerTotal>[];
  var sumOfDinerTotals = 0;
  for (final d in diners) {
    final sub = subtotals[d.id] ?? 0;
    final tax = taxShares[d.id] ?? 0;
    final svc = serviceShares[d.id] ?? 0;
    final total = sub + tax + svc;
    sumOfDinerTotals += total;
    perDiner.add(DinerTotal(
      diner: d,
      subtotalCents: sub,
      taxShareCents: tax,
      serviceShareCents: svc,
      grandTotalCents: total,
    ));
  }

  final billGrandTotal = totalSubtotalCents + taxCents + serviceCents;
  final residual = billGrandTotal - sumOfDinerTotals;

  return BillTotals(
    perDiner: perDiner,
    billGrandTotalCents: billGrandTotal,
    roundingResidualCents: residual,
  );
}

void _allocateProportional({
  required int totalCents,
  required Map<String, int> subtotals,
  required Map<String, int> out,
}) {
  if (totalCents == 0) return;
  final totalSubtotal = subtotals.values.fold<int>(0, (a, b) => a + b);
  if (totalSubtotal == 0) return;

  // Largest-remainder method: floor each share, distribute the remainder one
  // cent at a time to whichever diner has the largest fractional remainder.
  var allocated = 0;
  final remainders = <MapEntry<String, double>>[];
  for (final entry in subtotals.entries) {
    final exact = totalCents * entry.value / totalSubtotal;
    final floored = exact.floor();
    out[entry.key] = floored;
    allocated += floored;
    remainders.add(MapEntry(entry.key, exact - floored));
  }
  var leftover = totalCents - allocated;
  remainders.sort((a, b) {
    final c = b.value.compareTo(a.value);
    if (c != 0) return c;
    return a.key.compareTo(b.key); // deterministic tiebreak
  });
  for (var i = 0; i < leftover && i < remainders.length; i++) {
    out[remainders[i].key] = (out[remainders[i].key] ?? 0) + 1;
  }
}

/// Items that have zero assigned diners — used to block finalize and to
/// surface a banner in the UI.
List<ReceiptItem> unassignedItems(
  List<ReceiptItem> items,
  AssignmentMap assignments,
) {
  return items
      .where((it) => (assignments[it.id] ?? const <String>{}).isEmpty)
      .toList(growable: false);
}
