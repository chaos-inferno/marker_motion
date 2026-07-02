## 0.2.0

This release removes the timer-based implementation to focus on a single, reliable
animation path, and fixes several correctness issues.

- **Breaking:** Removed the `Timer`-based animation implementation, the
  `MotionImplementation` enum, and the `implementation` and `frameRate` fields on
  `MarkerMotionConfig`. Configure animations with `duration` and `animationCurve` only.
- Fixed markers not updating when the same `Set` instance is mutated in place and
  re-submitted (for example, adding or removing a marker without allocating a new set).
- Fixed animated markers settling a hair off their target due to floating-point error;
  markers now snap to the exact target position when the animation completes.
- Fixed in-flight animations restarting whenever any other marker was added, removed, or
  changed. Each marker now animates on its own independent clock, so unrelated updates no
  longer disturb markers already in motion.

## 0.1.4

This release focuses on making marker updates more efficient and the package more reliable.

- Improved marker update performance by replacing repeated linear marker lookups with fast
  marker-id map lookups in both animation implementations.
- Reduced per-frame overhead in timer mode by removing debug logging during animation ticks.
- Ensured timer mode correctly respects `MarkerMotionConfig.frameRate` from `MarkerMotion`.
- Hardened timer step calculation for very short durations to avoid edge-case timing issues.
- Greatly expanded and refactored the test suite:
  - Added comprehensive behavior tests for animation and timer implementations, including
    no-op updates, add/remove flows, mid-flight retargeting, empty transitions, rapid updates,
    remove/re-add flows, tiny delta movements, and dispose safety.
  - Added implementation-specific tests for animation curve/duration updates and timer
    frame-rate behavior/cancellation.
  - Added configuration assertion tests for invalid `MarkerMotionConfig` combinations.
  - Simplified test structure with shared helpers and table-driven coverage to improve
    readability and maintainability.

## 0.1.3

- Make sure that the frame rate is between 1 - 120 (inclusive).
- Update the README

## 0.1.2

Fixed formatting.

## 0.1.1

Reformatted code for pub points.

## 0.1.0

Initial release of the marker_motion package. Using the MarkerMotion widget you can animate
multiple markers on a GoogleMap widget between two positions. It also allows you to choose the
underlying implementation to use either an AnimationController driven animation, or a simpler
Timer based one.
