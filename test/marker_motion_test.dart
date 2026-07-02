import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_motion/marker_motion.dart';

Marker _marker(
  String id,
  double lat,
  double lng, {
  double rotation = 0,
  double alpha = 1,
  bool draggable = false,
  bool consumeTapEvents = false,
  bool flat = false,
  bool visible = true,
  int zIndexInt = 0,
  InfoWindow infoWindow = InfoWindow.noText,
}) {
  return Marker(
    markerId: MarkerId(id),
    position: LatLng(lat, lng),
    rotation: rotation,
    alpha: alpha,
    draggable: draggable,
    consumeTapEvents: consumeTapEvents,
    flat: flat,
    visible: visible,
    zIndexInt: zIndexInt,
    infoWindow: infoWindow,
  );
}

Marker _byId(Set<Marker> markers, String id) {
  return markers.firstWhere((m) => m.markerId.value == id);
}

Set<String> _ids(Set<Marker> markers) {
  return markers.map((m) => m.markerId.value).toSet();
}

Widget _harness({
  required Set<Marker> markers,
  required Duration duration,
  required void Function(Set<Marker>) onBuild,
  Curve animationCurve = Curves.linear,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MarkerMotion(
        markers: markers,
        config: MarkerMotionConfig(
          duration: duration,
          animationCurve: animationCurve,
        ),
        builder: (renderedMarkers) {
          onBuild(Set<Marker>.from(renderedMarkers));
          return const SizedBox();
        },
      ),
    ),
  );
}

Future<void> _pumpMotion(
  WidgetTester tester, {
  required Set<Marker> markers,
  required void Function(Set<Marker>) onBuild,
  Duration duration = const Duration(milliseconds: 1000),
  Curve animationCurve = Curves.linear,
}) {
  return tester.pumpWidget(
    _harness(
      markers: markers,
      duration: duration,
      animationCurve: animationCurve,
      onBuild: onBuild,
    ),
  );
}

Future<void> _pumpUntilComplete(
  WidgetTester tester, {
  required Duration duration,
}) async {
  await tester.pump(duration + const Duration(milliseconds: 16));
}

void main() {
  group('Behavior', () {
    testWidgets('no-op updates do not animate', (tester) async {
      final initial = {_marker('1', 37.7749, -122.4194, rotation: 10)};
      final updatedSamePosition = {
        _marker('1', 37.7749, -122.4194, rotation: 35),
      };

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: updatedSamePosition,
        onBuild: (markers) => rendered = markers,
      );

      final afterUpdate = _byId(rendered, '1');
      expect(afterUpdate.position, const LatLng(37.7749, -122.4194));
      expect(afterUpdate.rotation, 35);

      await tester.pump(const Duration(milliseconds: 500));
      expect(_byId(rendered, '1').position, const LatLng(37.7749, -122.4194));
    });

    testWidgets('add/remove behavior is correct', (tester) async {
      final initial = {_marker('1', 1, 1), _marker('2', 2, 2)};
      final updated = {_marker('2', 2, 2), _marker('3', 3, 3)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: const Duration(milliseconds: 500),
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: updated,
        duration: const Duration(milliseconds: 500),
        onBuild: (markers) => rendered = markers,
      );

      expect(_ids(rendered), {'2', '3'});
      expect(() => _byId(rendered, '1'), throwsStateError);
      expect(_byId(rendered, '3').position, const LatLng(3, 3));
    });

    testWidgets('mid-flight update retargets marker', (tester) async {
      final initial = {_marker('1', 0, 0)};
      final firstTarget = {_marker('1', 10, 0)};
      final secondTarget = {_marker('1', 20, 0)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: const Duration(milliseconds: 2000),
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: firstTarget,
        duration: const Duration(milliseconds: 2000),
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 500));
      final midFirstLegLat = _byId(rendered, '1').position.latitude;
      expect(midFirstLegLat, greaterThan(0));
      expect(midFirstLegLat, lessThan(10));

      await _pumpMotion(
        tester,
        markers: secondTarget,
        duration: const Duration(milliseconds: 2000),
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 500));
      final afterRetargetLat = _byId(rendered, '1').position.latitude;
      expect(afterRetargetLat, greaterThan(midFirstLegLat));
      expect(afterRetargetLat, lessThan(20));

      await _pumpUntilComplete(
        tester,
        duration: const Duration(milliseconds: 2000),
      );
      expect(_byId(rendered, '1').position, const LatLng(20, 0));
    });

    testWidgets('unchanged targets do not stall in-flight animation', (
      tester,
    ) async {
      final initial = {_marker('1', 0, 0)};
      Set<Marker> target() => {_marker('1', 10, 0)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: const Duration(milliseconds: 1000),
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: target(),
        duration: const Duration(milliseconds: 1000),
        onBuild: (markers) => rendered = markers,
      );

      // The parent keeps rebuilding with identical target content (a fresh
      // Set instance each time) while the animation runs. This must not
      // restart the animation; the marker must still settle on target.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await _pumpMotion(
          tester,
          markers: target(),
          duration: const Duration(milliseconds: 1000),
          onBuild: (markers) => rendered = markers,
        );
      }

      // 30 * 50ms = 1500ms elapsed, well past the 1000ms duration.
      expect(_byId(rendered, '1').position, const LatLng(10, 0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('transition to empty clears markers', (tester) async {
      final initial = {_marker('1', 5, 5)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: const {},
        onBuild: (markers) => rendered = markers,
      );

      expect(rendered, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(rendered, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('very short duration lands on target', (tester) async {
      final initial = {_marker('1', 0, 0)};
      final target = {_marker('1', 1, 1)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: const Duration(milliseconds: 1),
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: target,
        duration: const Duration(milliseconds: 1),
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 20));
      expect(_byId(rendered, '1').position, const LatLng(1, 1));
    });

    testWidgets('duration.zero reaches target quickly', (tester) async {
      final initial = {_marker('1', 0, 0)};
      final target = {_marker('1', 10, 10)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: Duration.zero,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: target,
        duration: Duration.zero,
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 20));
      expect(_byId(rendered, '1').position, const LatLng(10, 10));
      expect(tester.takeException(), isNull);
    });

    testWidgets('multi-marker mixed update behaves correctly', (tester) async {
      final initial = {
        _marker('1', 1, 1),
        _marker('2', 2, 2),
        _marker('3', 3, 3),
      };
      final updated = {
        _marker('1', 1, 1),
        _marker('2', 20, 2),
        _marker('4', 4, 4),
      };

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: updated,
        onBuild: (markers) => rendered = markers,
      );

      expect(_ids(rendered), {'1', '2', '4'});
      expect(_byId(rendered, '1').position, const LatLng(1, 1));
      expect(_byId(rendered, '2').position, const LatLng(2, 2));
      expect(_byId(rendered, '4').position, const LatLng(4, 4));

      await tester.pump(const Duration(milliseconds: 500));
      final movingMid = _byId(rendered, '2').position.latitude;
      expect(movingMid, greaterThan(2));
      expect(movingMid, lessThan(20));

      await tester.pump(const Duration(milliseconds: 700));
      expect(_byId(rendered, '2').position, const LatLng(20, 2));
    });

    testWidgets('marker fields are preserved while animating position', (
      tester,
    ) async {
      final initial = {
        _marker(
          '1',
          10,
          10,
          rotation: 42,
          alpha: 0.5,
          draggable: true,
          consumeTapEvents: true,
          flat: true,
          visible: true,
          zIndexInt: 7,
          infoWindow: const InfoWindow(title: 'A', snippet: 'B'),
        ),
      };
      final target = {
        _marker(
          '1',
          20,
          20,
          rotation: 42,
          alpha: 0.5,
          draggable: true,
          consumeTapEvents: true,
          flat: true,
          visible: true,
          zIndexInt: 7,
          infoWindow: const InfoWindow(title: 'A', snippet: 'B'),
        ),
      };

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: target,
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 500));
      final mid = _byId(rendered, '1');

      expect(mid.position, isNot(const LatLng(10, 10)));
      expect(mid.position, isNot(const LatLng(20, 20)));
      expect(mid.rotation, 42);
      expect(mid.alpha, 0.5);
      expect(mid.draggable, isTrue);
      expect(mid.consumeTapEvents, isTrue);
      expect(mid.flat, isTrue);
      expect(mid.visible, isTrue);
      expect(mid.zIndexInt, 7);
      expect(mid.infoWindow, const InfoWindow(title: 'A', snippet: 'B'));
    });

    testWidgets('dispose safety', (tester) async {
      final initial = {_marker('1', 0, 0)};
      final target = {_marker('1', 10, 10)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: const Duration(milliseconds: 2000),
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: target,
        duration: const Duration(milliseconds: 2000),
        onBuild: (markers) => rendered = markers,
      );

      expect(rendered, isNotEmpty);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapid successive updates land on latest target', (
      tester,
    ) async {
      final p0 = {_marker('1', 0, 0)};
      final p1 = {_marker('1', 10, 0)};
      final p2 = {_marker('1', 20, 0)};
      final p3 = {_marker('1', 30, 0)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: p0,
        duration: const Duration(milliseconds: 800),
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: p1,
        duration: const Duration(milliseconds: 800),
        onBuild: (markers) => rendered = markers,
      );
      await tester.pump(const Duration(milliseconds: 120));

      await _pumpMotion(
        tester,
        markers: p2,
        duration: const Duration(milliseconds: 800),
        onBuild: (markers) => rendered = markers,
      );
      await tester.pump(const Duration(milliseconds: 120));

      await _pumpMotion(
        tester,
        markers: p3,
        duration: const Duration(milliseconds: 800),
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 1000));
      expect(_byId(rendered, '1').position, const LatLng(30, 0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('duplicate marker ids do not crash', (tester) async {
      final initial = {_marker('1', 0, 0)};
      final duplicates = <Marker>{_marker('1', 10, 0), _marker('1', 20, 0)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: const Duration(milliseconds: 400),
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: duplicates,
        duration: const Duration(milliseconds: 400),
        onBuild: (markers) => rendered = markers,
      );

      await _pumpUntilComplete(
        tester,
        duration: const Duration(milliseconds: 400),
      );
      expect(
        _byId(rendered, '1').position,
        anyOf(const LatLng(10, 0), const LatLng(20, 0)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('remove then re-add marker works', (tester) async {
      final initial = {_marker('1', 0, 0)};
      final readded = {_marker('1', 5, 5)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: const Duration(milliseconds: 300),
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: const {},
        duration: const Duration(milliseconds: 300),
        onBuild: (markers) => rendered = markers,
      );
      expect(rendered, isEmpty);

      await _pumpMotion(
        tester,
        markers: readded,
        duration: const Duration(milliseconds: 300),
        onBuild: (markers) => rendered = markers,
      );

      await tester.pumpAndSettle();
      expect(_byId(rendered, '1').position, const LatLng(5, 5));
    });

    testWidgets('tiny movement delta completes correctly', (tester) async {
      const start = LatLng(37.0, -122.0);
      const end = LatLng(37.0000001, -122.0000001);

      final initial = {Marker(markerId: const MarkerId('1'), position: start)};
      final target = {Marker(markerId: const MarkerId('1'), position: end)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: const Duration(milliseconds: 500),
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: target,
        duration: const Duration(milliseconds: 500),
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 250));
      final mid = _byId(rendered, '1').position;
      expect(mid.latitude, greaterThan(start.latitude));
      expect(mid.latitude, lessThan(end.latitude));

      await _pumpUntilComplete(
        tester,
        duration: const Duration(milliseconds: 500),
      );
      expect(_byId(rendered, '1').position, end);
    });
  });

  group('Animation-specific behavior', () {
    testWidgets('curve affects midpoint as expected', (tester) async {
      final initial = {_marker('1', 0, 0)};
      final target = {_marker('1', 10, 0)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: const Duration(milliseconds: 1000),
        animationCurve: Curves.easeIn,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: target,
        duration: const Duration(milliseconds: 1000),
        animationCurve: Curves.easeIn,
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 500));
      final easedMidLat = _byId(rendered, '1').position.latitude;

      expect(easedMidLat, greaterThan(0));
      expect(easedMidLat, lessThan(5));

      await tester.pump(const Duration(milliseconds: 600));
      expect(_byId(rendered, '1').position, const LatLng(10, 0));
    });

    testWidgets('runtime duration and curve updates are applied', (
      tester,
    ) async {
      final p0 = {_marker('1', 0, 0)};
      final p1 = {_marker('1', 10, 0)};
      final p2 = {_marker('1', 20, 0)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: p0,
        duration: const Duration(milliseconds: 3000),
        animationCurve: Curves.linear,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: p1,
        duration: const Duration(milliseconds: 3000),
        animationCurve: Curves.linear,
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 500));
      final slowMid = _byId(rendered, '1').position.latitude;
      expect(slowMid, lessThan(3));

      await _pumpMotion(
        tester,
        markers: p2,
        duration: const Duration(milliseconds: 300),
        animationCurve: Curves.easeIn,
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 150));
      final secondMid = _byId(rendered, '1').position.latitude;
      expect(secondMid, greaterThan(slowMid));
      expect(secondMid, lessThan(15));

      await tester.pump(const Duration(milliseconds: 250));
      expect(_byId(rendered, '1').position, const LatLng(20, 0));
    });
  });

  group('Regression', () {
    // Mutating and re-submitting the same Set instance (as the example
    // app's add/remove buttons do) must still surface the change.
    testWidgets('in-place Set mutation is reflected (add then remove)', (
      tester,
    ) async {
      final markers = <Marker>{_marker('1', 0, 0)};

      Set<Marker> rendered = {};

      await _pumpMotion(tester, markers: markers, onBuild: (m) => rendered = m);
      expect(_ids(rendered), {'1'});

      // Add to the SAME instance and rebuild.
      markers.add(_marker('2', 1, 1));
      await _pumpMotion(tester, markers: markers, onBuild: (m) => rendered = m);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_ids(rendered), {'1', '2'});

      // Remove from the SAME instance and rebuild.
      markers.removeWhere((m) => m.markerId.value == '1');
      await _pumpMotion(tester, markers: markers, onBuild: (m) => rendered = m);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_ids(rendered), {'2'});
    });

    // On completion the marker must rest on the exact target, not a
    // float-error approximation of it (which also prevented spurious re-animation
    // on the next identical update).
    testWidgets('animation settles on the exact target coordinates', (
      tester,
    ) async {
      const target = LatLng(37.123456, -122.654321);
      final initial = {_marker('1', 10, 10)};
      final moved = {Marker(markerId: const MarkerId('1'), position: target)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: const Duration(milliseconds: 300),
        onBuild: (m) => rendered = m,
      );
      await _pumpMotion(
        tester,
        markers: moved,
        duration: const Duration(milliseconds: 300),
        onBuild: (m) => rendered = m,
      );

      await _pumpUntilComplete(
        tester,
        duration: const Duration(milliseconds: 300),
      );
      expect(_byId(rendered, '1').position, target);
    });

    // Adding/removing/changing an unrelated marker must not reset the
    // clock of a marker already in flight; it should still arrive on schedule.
    testWidgets('unrelated add does not reset an in-flight marker clock', (
      tester,
    ) async {
      final initial = {_marker('1', 0, 0)};
      final moving = {_marker('1', 100, 0)};
      final movingPlusStatic = {_marker('1', 100, 0), _marker('2', 5, 5)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        duration: const Duration(milliseconds: 1000),
        onBuild: (m) => rendered = m,
      );
      await _pumpMotion(
        tester,
        markers: moving,
        duration: const Duration(milliseconds: 1000),
        onBuild: (m) => rendered = m,
      );

      await tester.pump(const Duration(milliseconds: 500)); // ~halfway
      final halfway = _byId(rendered, '1').position.latitude;
      expect(halfway, greaterThan(0));
      expect(halfway, lessThan(100));

      // Add an unrelated static marker; marker '1' keeps the same target.
      await _pumpMotion(
        tester,
        markers: movingPlusStatic,
        duration: const Duration(milliseconds: 1000),
        onBuild: (m) => rendered = m,
      );

      // Pump the remaining budget of the ORIGINAL 1000ms animation.
      await tester.pump(const Duration(milliseconds: 520));

      // Marker '1' arrived on its original schedule (clock was not reset) and
      // the static marker is present and untouched.
      expect(_byId(rendered, '1').position, const LatLng(100, 0));
      expect(_byId(rendered, '2').position, const LatLng(5, 5));
    });

    // Two markers that start moving at different times must
    // each run their own clock and therefore finish at different times.
    testWidgets('staggered markers animate on independent clocks', (
      tester,
    ) async {
      const dur = Duration(milliseconds: 1000);

      Set<Marker> rendered = {};

      // Both markers start at the origin.
      await _pumpMotion(
        tester,
        markers: {_marker('a', 0, 0), _marker('b', 0, 0)},
        duration: dur,
        onBuild: (m) => rendered = m,
      );

      // 'a' starts moving; 'b' stays put.
      await _pumpMotion(
        tester,
        markers: {_marker('a', 100, 0), _marker('b', 0, 0)},
        duration: dur,
        onBuild: (m) => rendered = m,
      );

      await tester.pump(const Duration(milliseconds: 500)); // a ~halfway
      expect(_byId(rendered, 'a').position.latitude, greaterThan(0));
      expect(_byId(rendered, 'a').position.latitude, lessThan(100));
      expect(_byId(rendered, 'b').position, const LatLng(0, 0));

      // 'b' starts moving 500ms after 'a'; 'a' keeps its original target and
      // must not have its clock reset.
      await _pumpMotion(
        tester,
        markers: {_marker('a', 100, 0), _marker('b', 0, 100)},
        duration: dur,
        onBuild: (m) => rendered = m,
      );

      // At ~1000ms total, 'a' (started at 0ms) has arrived; 'b' (started at
      // ~500ms) is only about halfway.
      await tester.pump(const Duration(milliseconds: 500));
      expect(_byId(rendered, 'a').position, const LatLng(100, 0));
      final bLng = _byId(rendered, 'b').position.longitude;
      expect(bLng, greaterThan(0));
      expect(bLng, lessThan(100));

      // ~500ms later 'b' completes too, and 'a' has not drifted off target.
      await tester.pump(const Duration(milliseconds: 500));
      expect(_byId(rendered, 'a').position, const LatLng(100, 0));
      expect(_byId(rendered, 'b').position, const LatLng(0, 100));
      expect(tester.takeException(), isNull);
    });
  });
}
