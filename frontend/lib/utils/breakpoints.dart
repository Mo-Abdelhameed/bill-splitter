import 'package:flutter/widgets.dart';

/// Responsive-layout breakpoints per the spec-kit feature plan
/// (`specs/001-bill-split-flow/research.md` R-5).
///
/// Width thresholds (logical pixels):
/// - `< 600`        → phone portrait
/// - `600..899`     → phone landscape / small tablet
/// - `>= 900`       → tablet (portrait or landscape)
enum Breakpoint {
  phonePortrait,
  phoneLandscapeOrSmallTablet,
  tablet,
}

const double _phoneLandscapeStart = 600;
const double _tabletStart = 900;

/// Resolve the current viewport into a [Breakpoint] using [MediaQuery].
Breakpoint breakpointFor(BuildContext context) {
  final double width = MediaQuery.of(context).size.width;
  if (width >= _tabletStart) {
    return Breakpoint.tablet;
  }
  if (width >= _phoneLandscapeStart) {
    return Breakpoint.phoneLandscapeOrSmallTablet;
  }
  return Breakpoint.phonePortrait;
}
