import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'animated_marker.dart';

/// The animation implementation for [MarkerMotion].
class MarkerMotionAnimation extends StatefulWidget {
  /// Creates a [MarkerMotionAnimation] widget to animate Google Maps markers.
  ///
  /// The [markers] parameter specifies the current set of markers to display and animate.
  /// When this set updates, markers with matching [MarkerId]s will animate to their new
  /// positions. The [builder] parameter defines how to render the animated markers,
  /// typically within a [GoogleMap] widget. The [duration] and [animationCurve] control
  /// the animation’s timing and easing behavior.
  const MarkerMotionAnimation({
    super.key,
    required this.markers,
    required this.builder,
    this.duration = const Duration(milliseconds: 3200),
    this.animationCurve = Curves.linear,
  });

  /// The set of target markers with their final positions.
  ///
  /// When this set changes, markers are animated from their previous positions to the
  /// new ones based on their [MarkerId]. Markers not present in the new set are removed.
  final Set<Marker> markers;

  /// A function that builds a widget using the current set of animated markers.
  ///
  /// This is typically used to pass the animated markers to a [GoogleMap] widget.
  final Widget Function(Set<Marker> markers) builder;

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

  @override
  State<MarkerMotionAnimation> createState() => _MarkerMotionAnimationState();
}

/// The state class managing the animation logic for [MarkerMotion].
class _MarkerMotionAnimationState extends State<MarkerMotionAnimation>
    with SingleTickerProviderStateMixin {
  /// The current set of markers displayed on the map, including those animating.
  Set<Marker> _displayMarkers = {};

  /// A snapshot of the most recently applied target set.
  ///
  /// Change detection compares incoming markers against this snapshot rather
  /// than `oldWidget.markers`, so callers that mutate and re-submit the same
  /// [Set] instance are still handled correctly.
  Set<Marker> _lastTarget = {};

  /// Markers currently animating, keyed by id. Each entry carries its own
  /// start/end positions and start time, giving every marker an independent
  /// animation clock.
  final Map<MarkerId, AnimatedMarker> _animatedMarkers = {};

  /// Drives per-frame position updates while any marker is animating.
  late final Ticker _ticker;

  /// The latest elapsed time reported by [_ticker] for the current run.
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Start with the initial set of markers.
    _displayMarkers = Set<Marker>.from(widget.markers);
    _lastTarget = Set<Marker>.from(widget.markers);
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant MarkerMotionAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detect changes against our own snapshot rather than oldWidget.markers, so
    // callers that mutate and re-submit the same Set instance are handled.
    // Duration and curve are read live in _updateAnimations, so runtime changes
    // to them apply automatically without needing to be handled here.
    if (setEquals(widget.markers, _lastTarget)) {
      return;
    }
    _lastTarget = Set<Marker>.from(widget.markers);

    // Clear everything and stop if no markers are provided.
    if (widget.markers.isEmpty) {
      _animatedMarkers.clear();
      _ticker.stop();
      setState(() => _displayMarkers = {});
      return;
    }

    final newMarkersById = <MarkerId, Marker>{
      for (final marker in widget.markers) marker.markerId: marker,
    };
    final currentDisplayById = <MarkerId, Marker>{
      for (final marker in _displayMarkers) marker.markerId: marker,
    };

    // Legs started during this pass are timed from the current clock value.
    // When the ticker is idle there are no in-flight markers, so a fresh run
    // begins from zero.
    final now = _ticker.isActive ? _elapsed : Duration.zero;

    for (final newMarker in widget.markers) {
      final id = newMarker.markerId;
      final currentPos = currentDisplayById[id]?.position;

      // Brand-new marker (no current position) or already at its target:
      // nothing to animate.
      if (currentPos == null || currentPos == newMarker.position) {
        _animatedMarkers.remove(id);
        continue;
      }

      final existing = _animatedMarkers[id];
      if (existing != null && existing.end == newMarker.position) {
        // Target unchanged (some other marker or a non-position field changed):
        // keep this marker's clock running and just refresh its fields.
        _animatedMarkers[id] = AnimatedMarker(
          start: existing.start,
          end: existing.end,
          marker: newMarker,
          startedAt: existing.startedAt,
        );
      } else {
        // Newly moving or retargeted: start a fresh leg from the current
        // on-screen position on its own clock.
        _animatedMarkers[id] = AnimatedMarker(
          start: currentPos,
          end: newMarker.position,
          marker: newMarker,
          startedAt: now,
        );
      }
    }

    // Drop animations for markers that are no longer present.
    _animatedMarkers.removeWhere((id, _) => !newMarkersById.containsKey(id));

    // Assemble the display set: animating markers keep their current on-screen
    // position (refreshed on the next tick); everything else is taken as-is.
    _displayMarkers = {
      ..._displayMarkers.where((m) => _animatedMarkers.containsKey(m.markerId)),
      ...widget.markers.where((m) => !_animatedMarkers.containsKey(m.markerId)),
    };

    if (_animatedMarkers.isEmpty) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _elapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    _updateAnimations();
  }

  /// Recomputes marker positions from each marker’s independent clock.
  void _updateAnimations() {
    if (_animatedMarkers.isEmpty) return;

    final curve = widget.animationCurve;
    final durationMicros = widget.duration.inMicroseconds;

    final updatedMarkers = <Marker>{};

    // Keep markers that aren’t animating unchanged.
    for (final marker in _displayMarkers) {
      if (!_animatedMarkers.containsKey(marker.markerId)) {
        updatedMarkers.add(marker);
      }
    }

    // Interpolate positions for animating markers, each on its own clock.
    final completed = <MarkerId>[];
    for (final entry in _animatedMarkers.entries) {
      final animatedMarker = entry.value;
      final elapsedMicros =
          (_elapsed - animatedMarker.startedAt).inMicroseconds;

      final t = durationMicros <= 0
          ? 1.0
          : (elapsedMicros / durationMicros).clamp(0.0, 1.0);

      final LatLng position;
      if (t >= 1.0) {
        // Snap to the exact target so the marker settles precisely on it.
        position = animatedMarker.end;
        completed.add(entry.key);
      } else {
        position = animatedMarker.lerp(curve.transform(t));
      }

      updatedMarkers.add(
        animatedMarker.marker.copyWith(positionParam: position),
      );
    }

    // Clean up completed animations.
    for (final id in completed) {
      _animatedMarkers.remove(id);
    }

    // Update the displayed markers and trigger a rebuild.
    setState(() => _displayMarkers = updatedMarkers);

    // Stop ticking once every marker has settled.
    if (_animatedMarkers.isEmpty) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_displayMarkers);
  }
}
