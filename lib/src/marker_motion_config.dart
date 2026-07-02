import 'package:flutter/material.dart';

/// Configuration options for the [MarkerMotion] widget.
///
/// Pass an instance to `MarkerMotion.config` to customize how markers animate
/// between positions.
class MarkerMotionConfig {
  const MarkerMotionConfig({
    this.duration = const Duration(milliseconds: 3200),
    this.animationCurve = Curves.linear,
  });

  /// The duration of the marker movement animation.
  ///
  /// Defaults to 3200 milliseconds (3.2 seconds). Adjust this to control how long the
  /// animation takes to complete.
  final Duration duration;

  /// The animation curve applied to marker movements.
  ///
  /// Defaults to [Curves.linear] for a constant speed. Use other curves (e.g.,
  /// [Curves.easeInOut]) for different animation effects.
  final Curve animationCurve;
}
