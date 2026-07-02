import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A helper class to manage the animation of a single marker.
///
/// Stores the start and end positions along with the time the animation leg
/// began, and provides linear interpolation (lerp) for smooth transitions.
class AnimatedMarker {
  AnimatedMarker({
    required this.start,
    required this.end,
    required this.marker,
    required this.startedAt,
  });

  /// The marker’s starting position.
  final LatLng start;

  /// The marker’s target position.
  final LatLng end;

  /// The marker being animated, containing all properties except position.
  final Marker marker;

  /// The animation clock time (ticker elapsed) at which this leg started.
  ///
  /// Each marker tracks its own start time so that adding, removing, or
  /// retargeting one marker never disturbs the timing of the others.
  final Duration startedAt;

  /// Interpolates between [start] and [end] positions based on [t] (0.0 to 1.0).
  LatLng lerp(double t) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * t,
      start.longitude + (end.longitude - start.longitude) * t,
    );
  }
}
