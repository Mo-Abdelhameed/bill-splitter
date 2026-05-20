import 'dart:math' as math;

/// Round up to the nearest whole EGP — FR-015 / SC-003.
///
/// Per-person final totals must never round *down*, so that the sum across
/// all people is always ≥ the raw grand total (nobody underpays).
int roundUpEgp(num value) => math.max(value.ceil(), 0);
