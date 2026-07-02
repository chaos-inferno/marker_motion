import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'animated_marker.dart';

/// The animation implementation for [MarkerMotion].
class MarkerMotionAnimation extends StatefulWidget {
  /// Creates a [MarkerMotionAnimation] widget to animate Google Maps markers using
  /// and animation controller.
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
  /// The current set of markers displayed on the map, including those being animated.
  Set<Marker> _displayMarkers = {};

  /// Tracks markers currently being animated, storing their start and end positions.
  final Map<MarkerId, AnimatedMarker> _animatedMarkers = {};

  /// Controls the animation timing for all marker movements.
  late AnimationController _controller;

  /// Applies the specified [animationCurve] to the animation progress.
  late CurvedAnimation _curvedAnimation;

  @override
  void initState() {
    super.initState();
    // Start with the initial set of markers
    _displayMarkers = Set<Marker>.from(widget.markers);

    // Set up the animation controller with the specified duration
    _controller = AnimationController(vsync: this, duration: widget.duration);

    // Apply the animation curve to the controller’s progress
    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    );

    // Listen for animation updates to reposition markers
    _controller.addListener(_updateAnimations);
  }

  @override
  void didUpdateWidget(covariant MarkerMotionAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animation settings if they’ve changed
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }

    // Update the animation curve if it's changed
    if (widget.animationCurve != oldWidget.animationCurve) {
      _curvedAnimation.dispose();
      _curvedAnimation = CurvedAnimation(
        parent: _controller,
        curve: widget.animationCurve,
      );
    }

    if (setEquals(widget.markers, oldWidget.markers)) {
      return;
    }

    // Clear everything and return early if no markers are provided
    if (widget.markers.isEmpty) {
      _animatedMarkers.clear();
      setState(() => _displayMarkers = {});
      return;
    }

    // Identify markers that need animation by comparing old and new positions
    final newMarkersById = <MarkerId, Marker>{
      for (final marker in widget.markers) marker.markerId: marker,
    };

    _animatedMarkers.clear();
    for (final oldMarker in _displayMarkers) {
      final newMarker = newMarkersById[oldMarker.markerId];

      // Skip markers that were removed or haven’t changed position
      if (newMarker == null || oldMarker.position == newMarker.position) {
        continue;
      }

      // Queue the marker for animation with its start and end positions
      _animatedMarkers[oldMarker.markerId] = AnimatedMarker(
        start: oldMarker.position,
        end: newMarker.position,
        marker: newMarker,
      );
    }

    // Update the display set: keep animating markers, add non-animating ones
    _displayMarkers = {
      ..._displayMarkers.where((m) => _animatedMarkers.containsKey(m.markerId)),
      ...widget.markers.where((m) => !_animatedMarkers.containsKey(m.markerId)),
    };

    // Start the animation if there are markers to animate
    if (_animatedMarkers.isNotEmpty) {
      _controller.forward(from: 0.0);
    }
  }

  /// Updates marker positions based on the current animation progress.
  void _updateAnimations() {
    if (_animatedMarkers.isEmpty) return;

    final updatedMarkers = <Marker>{};

    // Save markers that aren’t being animated
    for (final marker in _displayMarkers) {
      if (!_animatedMarkers.containsKey(marker.markerId)) {
        updatedMarkers.add(marker);
      }
    }

    // Interpolate positions for animating markers
    for (final animatedMarker in _animatedMarkers.values) {
      final position = animatedMarker.lerp(_curvedAnimation.value);

      // Update the marker with its new interpolated position
      updatedMarkers.add(
        animatedMarker.marker.copyWith(positionParam: position),
      );
    }

    // Update the displayed markers and trigger a rebuild
    setState(() {
      _displayMarkers = updatedMarkers;
    });

    // Clean up completed animations
    if (_controller.status == AnimationStatus.completed) {
      _animatedMarkers.clear();
    }
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_displayMarkers);
  }
}
