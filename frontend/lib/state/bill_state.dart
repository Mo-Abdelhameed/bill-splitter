import 'dart:typed_data';

import 'package:bill_split/state/bill_item.dart';

/// Holds the in-memory state of the current bill split.
///
/// Intentionally simple holder (no state-management package) per project
/// decision (2026-05-19). Passed down the widget tree via constructor injection
/// from the app root.
class BillState {
  /// People who are sharing the bill, in the order they were entered.
  /// Names are trimmed and deduplicated by the People screen (FR-001/FR-017),
  /// so they double as person identifiers downstream — the assignments map
  /// below keys assignees by this trimmed name.
  List<String> people = <String>[];

  /// Raw bytes of the captured receipt image. Set upstream (camera/gallery
  /// story, not yet defined). Read by the extraction screen.
  Uint8List? imageBytes;

  /// Items committed by the extraction screen. Each entry is one purchasable
  /// unit; quantity > 1 items are expanded into multiple entries (FR-003).
  /// Each item carries a UUID generated at commit time — used as the key in
  /// [assignments] so that two items with the same name+price stay distinct.
  List<BillItem> items = <BillItem>[];

  /// Tax amount listed on the receipt (or set by the user); null if not
  /// applicable / not present.
  double? tax;

  /// Whether tax is already included in the item prices (FR-009) vs. added
  /// on top (FR-010). User chooses on the Extraction screen via the
  /// segmented "Included in items / Added on top" control under the Tax
  /// checkbox. Default `false` ("Added on top") — the common Egyptian
  /// receipt format where VAT appears as a separate line in the subtotal
  /// math.
  bool taxIncluded = false;

  /// Service-charge amount; null if not applicable / not present.
  double? service;

  /// Same shape and default as [taxIncluded].
  bool serviceIncluded = false;

  /// Map keyed by item.id → personName → weight. A person not present on an
  /// item is not assigned. Weight defaults to 1; the Assignment screen lets
  /// the user edit it (FR-007a).
  Map<String, Map<String, double>> assignments =
      <String, Map<String, double>>{};

  /// Drop every recorded assignment. Called when the user edits the items
  /// list on the Extraction screen and re-commits, since item IDs are
  /// regenerated and stale assignments would point at items that no longer
  /// exist.
  void clearAssignments() {
    assignments = <String, Map<String, double>>{};
  }
}
