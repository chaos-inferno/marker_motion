import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'animated_marker.dart';

/// A widget that animates markers using a [Timer].
class MarkerMotionTimer extends StatefulWidget {
  /// Creates a [MarkerMotionTimer] widget to animate Google Maps markers using
  /// and animation controller.
  ///
  /// The [markers] parameter specifies the current set of markers to display and animate.
  /// When this set updates, markers with matching [MarkerId]s will animate to their new
  /// positions. The [builder] parameter defines how to render the animated markers,
  /// typically within a [GoogleMap] widget. The [duration] and [frameRate] control
  /// the animation’s duration and timing behavior with the [Timer].
  const MarkerMotionTimer({
    super.key,
    required this.markers,
    required this.builder,
    this.duration = const Duration(milliseconds: 3200),
    this.frameRate = 60,
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

  /// The frame rate of the marker movement animation.
  ///
  /// Defaults to 60 frames per second. Adjust this to control how often
  /// you want a new frame with updated marker positions to be emitted.
  final int frameRate;

  @override
  State<MarkerMotionTimer> createState() => _MarkerMotionTimerState();
}

class _MarkerMotionTimerState extends State<MarkerMotionTimer> {
  Set<Marker> _displayMarkers = {};
  final Map<MarkerId, AnimatedMarker> _animatedMarkers = {};
  Timer? _timer;
  double _timerProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _displayMarkers = Set<Marker>.from(widget.markers);
  }

  @override
  void didUpdateWidget(covariant MarkerMotionTimer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (setEquals(widget.markers, oldWidget.markers)) {
      return;
    }

    if (widget.markers.isEmpty) {
      _animatedMarkers.clear();
      _timer?.cancel();
      setState(() => _displayMarkers = {});
      return;
    }

    final newMarkersById = <MarkerId, Marker>{
      for (final marker in widget.markers) marker.markerId: marker,
    };

    _animatedMarkers.clear();
    for (final oldMarker in _displayMarkers) {
      final newMarker = newMarkersById[oldMarker.markerId];
      if (newMarker == null || oldMarker.position == newMarker.position) {
        continue;
      }

      _animatedMarkers[oldMarker.markerId] = AnimatedMarker(
        start: oldMarker.position,
        end: newMarker.position,
        marker: newMarker,
      );
    }

    _displayMarkers = {
      ..._displayMarkers.where((m) => _animatedMarkers.containsKey(m.markerId)),
      ...widget.markers.where((m) => !_animatedMarkers.containsKey(m.markerId)),
    };

    if (_animatedMarkers.isNotEmpty) {
      _startTimerAnimation();
    }
  }

  void _startTimerAnimation() {
    _timer?.cancel();
    _timerProgress = 0.0;

    final rawStepCount =
        (widget.duration.inMilliseconds / (1000 / widget.frameRate)).round();
    final stepCount = rawStepCount > 0 ? rawStepCount : 1;
    final stepSize = 1.0 / stepCount;

    _timer = Timer.periodic(
      Duration(milliseconds: (1000 / widget.frameRate).round()),
      (timer) {
        _timerProgress = (_timerProgress + stepSize).clamp(0.0, 1.0);

        if (_timerProgress >= 1.0) {
          _timerProgress = 1.0;
          timer.cancel();
          _updateAnimations();
          _animatedMarkers.clear();
        } else {
          _updateAnimations();
        }
      },
    );
  }

  void _updateAnimations() {
    if (_animatedMarkers.isEmpty) return;

    final updatedMarkers = <Marker>{};
    for (final marker in _displayMarkers) {
      if (!_animatedMarkers.containsKey(marker.markerId)) {
        updatedMarkers.add(marker);
      }
    }

    for (final animatedMarker in _animatedMarkers.values) {
      final position = (_timerProgress >= 1.0)
          ? animatedMarker.end
          : animatedMarker.lerp(_timerProgress);

      updatedMarkers.add(
        animatedMarker.marker.copyWith(positionParam: position),
      );
    }

    setState(() {
      _displayMarkers = updatedMarkers;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_displayMarkers);
  }
}
