import 'dart:typed_data';

import 'package:bill_split/state/bill_item.dart';

/// Holds the in-memory state of the current bill split.
///
/// Intentionally simple holder (no state-management package) per project
/// decision (2026-05-19). Passed down the widget tree via constructor injection
/// from the app root.
class BillState {
  /// People who are sharing the bill, in the order they were entered.
  List<String> people = <String>[];

  /// Raw bytes of the captured receipt image. Set upstream (camera/gallery
  /// story, not yet defined). Read by the extraction screen.
  Uint8List? imageBytes;

  /// Items committed by the extraction screen. Each entry is one purchasable
  /// unit; quantity > 1 items are expanded into multiple entries (STORY-002).
  List<BillItem> items = <BillItem>[];

  /// Tax amount listed on the receipt (or set by the user); null if not
  /// applicable / not present.
  double? tax;

  /// Service-charge amount; null if not applicable / not present.
  double? service;
}
