import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_motion/src/marker_motion_config.dart';

import 'marker_motion_animation.dart';

/// A widget that smoothly animates Google Maps markers between two positions.
///
/// [MarkerMotion] animates markers from their previous positions to new ones
/// whenever the provided [markers] set changes. It’s ideal for applications
/// where map markers need to move dynamically, such as tracking real-time
/// locations or updating points of interest.
///
/// Example usage:
/// ```dart
/// MarkerMotion(
///   markers: mapMarkers, // Set of Marker objects to animate
///   config: const MarkerMotionConfig(
///     duration: Duration(milliseconds: 5200),
///   ),
///   builder: (markers) {
///     return GoogleMap(
///       markers: markers,
///     );
///   },
/// )
/// ```
class MarkerMotion extends StatelessWidget {
  const MarkerMotion({
    super.key,
    required this.markers,
    required this.builder,
    this.config = const MarkerMotionConfig(),
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

  /// An object which contains the configuration options for the marker motion widget.
  ///
  /// For more details check out the [MarkerMotionConfig] class.
  final MarkerMotionConfig config;

  @override
  Widget build(BuildContext context) {
    return MarkerMotionAnimation(
      markers: markers,
      builder: builder,
      duration: config.duration,
      animationCurve: config.animationCurve,
    );
  }
}
