import 'package:flutter/material.dart';

/// Phases a screen can be in while it awaits asynchronous work.
enum LoadingPhase {
  idle,
  loading,
  success,
  error,
}

/// Renders a phase-driven view:
/// - [LoadingPhase.loading]  → centered [CircularProgressIndicator]
/// - [LoadingPhase.error]    → [errorChild] if provided, else [child]
/// - [LoadingPhase.idle] / [LoadingPhase.success] → [child]
///
/// Inline pattern per the spec-kit feature plan
/// (`specs/001-bill-split-flow/research.md` R-7).
class LoadingState extends StatelessWidget {
  final LoadingPhase phase;
  final Widget child;
  final Widget? errorChild;

  const LoadingState({
    super.key,
    required this.phase,
    required this.child,
    this.errorChild,
  });

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case LoadingPhase.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadingPhase.error:
        return errorChild ?? child;
      case LoadingPhase.idle:
      case LoadingPhase.success:
        return child;
    }
  }
}
