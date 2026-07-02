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
  required MotionImplementation implementation,
  required Duration duration,
  required void Function(Set<Marker>) onBuild,
  Curve animationCurve = Curves.linear,
  int frameRate = 60,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MarkerMotion(
        markers: markers,
        config: MarkerMotionConfig(
          implementation: implementation,
          duration: duration,
          animationCurve: animationCurve,
          frameRate: frameRate,
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
  required MotionImplementation implementation,
  required void Function(Set<Marker>) onBuild,
  Duration duration = const Duration(milliseconds: 1000),
  Curve animationCurve = Curves.linear,
  int frameRate = 60,
}) {
  assert(
    implementation == MotionImplementation.timer || frameRate == 60,
    'frameRate must remain 60 for MotionImplementation.animation in tests.',
  );

  return tester.pumpWidget(
    _harness(
      markers: markers,
      implementation: implementation,
      duration: duration,
      animationCurve: animationCurve,
      frameRate: frameRate,
      onBuild: onBuild,
    ),
  );
}

Future<void> _pumpUntilComplete(
  WidgetTester tester, {
  required MotionImplementation implementation,
  required Duration duration,
  int frameRate = 60,
}) async {
  if (implementation == MotionImplementation.timer) {
    final frameMs = (1000 / frameRate).round();
    await tester.pump(duration + Duration(milliseconds: frameMs * 2));
    return;
  }

  await tester.pump(duration + const Duration(milliseconds: 16));
}

void main() {
  group('MarkerMotionConfig assertions', () {
    test('rejects custom frameRate for animation implementation', () {
      expect(
        () => MarkerMotionConfig(frameRate: 30),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects timer frameRate below range', () {
      expect(
        () => MarkerMotionConfig(
          implementation: MotionImplementation.timer,
          frameRate: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects timer frameRate above range', () {
      expect(
        () => MarkerMotionConfig(
          implementation: MotionImplementation.timer,
          frameRate: 121,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects non-linear curve with timer implementation', () {
      expect(
        () => MarkerMotionConfig(
          implementation: MotionImplementation.timer,
          animationCurve: Curves.easeIn,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Shared behavior', () {
    for (final implementation in MotionImplementation.values) {
      final label = implementation.name;

      testWidgets('no-op updates do not animate ($label)', (tester) async {
        final initial = {_marker('1', 37.7749, -122.4194, rotation: 10)};
        final updatedSamePosition = {
          _marker('1', 37.7749, -122.4194, rotation: 35),
        };

        Set<Marker> rendered = {};

        await _pumpMotion(
          tester,
          markers: initial,
          implementation: implementation,
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: updatedSamePosition,
          implementation: implementation,
          onBuild: (markers) => rendered = markers,
        );

        final afterUpdate = _byId(rendered, '1');
        expect(afterUpdate.position, const LatLng(37.7749, -122.4194));
        expect(afterUpdate.rotation, 35);

        await tester.pump(const Duration(milliseconds: 500));
        expect(_byId(rendered, '1').position, const LatLng(37.7749, -122.4194));
      });

      testWidgets('add/remove behavior is correct ($label)', (tester) async {
        final initial = {_marker('1', 1, 1), _marker('2', 2, 2)};
        final updated = {_marker('2', 2, 2), _marker('3', 3, 3)};

        Set<Marker> rendered = {};

        await _pumpMotion(
          tester,
          markers: initial,
          implementation: implementation,
          duration: const Duration(milliseconds: 500),
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: updated,
          implementation: implementation,
          duration: const Duration(milliseconds: 500),
          onBuild: (markers) => rendered = markers,
        );

        expect(_ids(rendered), {'2', '3'});
        expect(() => _byId(rendered, '1'), throwsStateError);
        expect(_byId(rendered, '3').position, const LatLng(3, 3));
      });

      testWidgets('mid-flight update retargets marker ($label)', (
        tester,
      ) async {
        final initial = {_marker('1', 0, 0)};
        final firstTarget = {_marker('1', 10, 0)};
        final secondTarget = {_marker('1', 20, 0)};

        Set<Marker> rendered = {};

        await _pumpMotion(
          tester,
          markers: initial,
          implementation: implementation,
          duration: const Duration(milliseconds: 2000),
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: firstTarget,
          implementation: implementation,
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
          implementation: implementation,
          duration: const Duration(milliseconds: 2000),
          onBuild: (markers) => rendered = markers,
        );

        await tester.pump(const Duration(milliseconds: 500));
        final afterRetargetLat = _byId(rendered, '1').position.latitude;
        expect(afterRetargetLat, greaterThan(midFirstLegLat));
        expect(afterRetargetLat, lessThan(20));

        await _pumpUntilComplete(
          tester,
          implementation: implementation,
          duration: const Duration(milliseconds: 2000),
        );
        expect(_byId(rendered, '1').position, const LatLng(20, 0));
      });

      testWidgets('unchanged targets do not stall in-flight animation ($label)', (
        tester,
      ) async {
        final initial = {_marker('1', 0, 0)};
        Set<Marker> target() => {_marker('1', 10, 0)};

        Set<Marker> rendered = {};

        await _pumpMotion(
          tester,
          markers: initial,
          implementation: implementation,
          duration: const Duration(milliseconds: 1000),
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: target(),
          implementation: implementation,
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
            implementation: implementation,
            duration: const Duration(milliseconds: 1000),
            onBuild: (markers) => rendered = markers,
          );
        }

        // 30 * 50ms = 1500ms elapsed, well past the 1000ms duration.
        expect(_byId(rendered, '1').position, const LatLng(10, 0));
        expect(tester.takeException(), isNull);
      });

      testWidgets('transition to empty clears markers ($label)', (
        tester,
      ) async {
        final initial = {_marker('1', 5, 5)};

        Set<Marker> rendered = {};

        await _pumpMotion(
          tester,
          markers: initial,
          implementation: implementation,
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: const {},
          implementation: implementation,
          onBuild: (markers) => rendered = markers,
        );

        expect(rendered, isEmpty);
        await tester.pump(const Duration(seconds: 2));
        expect(rendered, isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('very short duration lands on target ($label)', (
        tester,
      ) async {
        final initial = {_marker('1', 0, 0)};
        final target = {_marker('1', 1, 1)};

        Set<Marker> rendered = {};

        await _pumpMotion(
          tester,
          markers: initial,
          implementation: implementation,
          duration: const Duration(milliseconds: 1),
          frameRate: implementation == MotionImplementation.timer ? 120 : 60,
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: target,
          implementation: implementation,
          duration: const Duration(milliseconds: 1),
          frameRate: implementation == MotionImplementation.timer ? 120 : 60,
          onBuild: (markers) => rendered = markers,
        );

        await tester.pump(const Duration(milliseconds: 20));
        expect(_byId(rendered, '1').position, const LatLng(1, 1));
      });

      testWidgets('duration.zero reaches target quickly ($label)', (
        tester,
      ) async {
        final initial = {_marker('1', 0, 0)};
        final target = {_marker('1', 10, 10)};

        Set<Marker> rendered = {};

        await _pumpMotion(
          tester,
          markers: initial,
          implementation: implementation,
          duration: Duration.zero,
          frameRate: implementation == MotionImplementation.timer ? 120 : 60,
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: target,
          implementation: implementation,
          duration: Duration.zero,
          frameRate: implementation == MotionImplementation.timer ? 120 : 60,
          onBuild: (markers) => rendered = markers,
        );

        await tester.pump(const Duration(milliseconds: 20));
        expect(_byId(rendered, '1').position, const LatLng(10, 10));
        expect(tester.takeException(), isNull);
      });

      testWidgets('multi-marker mixed update behaves correctly ($label)', (
        tester,
      ) async {
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
          implementation: implementation,
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: updated,
          implementation: implementation,
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

      testWidgets(
        'marker fields are preserved while animating position ($label)',
        (tester) async {
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
            implementation: implementation,
            onBuild: (markers) => rendered = markers,
          );

          await _pumpMotion(
            tester,
            markers: target,
            implementation: implementation,
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
        },
      );

      testWidgets('dispose safety ($label)', (tester) async {
        final initial = {_marker('1', 0, 0)};
        final target = {_marker('1', 10, 10)};

        Set<Marker> rendered = {};

        await _pumpMotion(
          tester,
          markers: initial,
          implementation: implementation,
          duration: const Duration(milliseconds: 2000),
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: target,
          implementation: implementation,
          duration: const Duration(milliseconds: 2000),
          onBuild: (markers) => rendered = markers,
        );

        expect(rendered, isNotEmpty);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
      });

      testWidgets('rapid successive updates land on latest target ($label)', (
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
          implementation: implementation,
          duration: const Duration(milliseconds: 800),
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: p1,
          implementation: implementation,
          duration: const Duration(milliseconds: 800),
          onBuild: (markers) => rendered = markers,
        );
        await tester.pump(const Duration(milliseconds: 120));

        await _pumpMotion(
          tester,
          markers: p2,
          implementation: implementation,
          duration: const Duration(milliseconds: 800),
          onBuild: (markers) => rendered = markers,
        );
        await tester.pump(const Duration(milliseconds: 120));

        await _pumpMotion(
          tester,
          markers: p3,
          implementation: implementation,
          duration: const Duration(milliseconds: 800),
          onBuild: (markers) => rendered = markers,
        );

        await tester.pump(const Duration(milliseconds: 1000));
        expect(_byId(rendered, '1').position, const LatLng(30, 0));
        expect(tester.takeException(), isNull);
      });

      testWidgets('duplicate marker ids do not crash ($label)', (tester) async {
        final initial = {_marker('1', 0, 0)};
        final duplicates = <Marker>{_marker('1', 10, 0), _marker('1', 20, 0)};

        Set<Marker> rendered = {};

        await _pumpMotion(
          tester,
          markers: initial,
          implementation: implementation,
          duration: const Duration(milliseconds: 400),
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: duplicates,
          implementation: implementation,
          duration: const Duration(milliseconds: 400),
          onBuild: (markers) => rendered = markers,
        );

        await _pumpUntilComplete(
          tester,
          implementation: implementation,
          duration: const Duration(milliseconds: 400),
        );
        expect(
          _byId(rendered, '1').position,
          anyOf(const LatLng(10, 0), const LatLng(20, 0)),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('remove then re-add marker works ($label)', (tester) async {
        final initial = {_marker('1', 0, 0)};
        final readded = {_marker('1', 5, 5)};

        Set<Marker> rendered = {};

        await _pumpMotion(
          tester,
          markers: initial,
          implementation: implementation,
          duration: const Duration(milliseconds: 300),
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: const {},
          implementation: implementation,
          duration: const Duration(milliseconds: 300),
          onBuild: (markers) => rendered = markers,
        );
        expect(rendered, isEmpty);

        await _pumpMotion(
          tester,
          markers: readded,
          implementation: implementation,
          duration: const Duration(milliseconds: 300),
          onBuild: (markers) => rendered = markers,
        );

        await tester.pumpAndSettle();
        expect(_byId(rendered, '1').position, const LatLng(5, 5));
      });

      testWidgets('tiny movement delta completes correctly ($label)', (
        tester,
      ) async {
        const start = LatLng(37.0, -122.0);
        const end = LatLng(37.0000001, -122.0000001);

        final initial = {
          Marker(markerId: const MarkerId('1'), position: start),
        };
        final target = {Marker(markerId: const MarkerId('1'), position: end)};

        Set<Marker> rendered = {};

        await _pumpMotion(
          tester,
          markers: initial,
          implementation: implementation,
          duration: const Duration(milliseconds: 500),
          onBuild: (markers) => rendered = markers,
        );

        await _pumpMotion(
          tester,
          markers: target,
          implementation: implementation,
          duration: const Duration(milliseconds: 500),
          onBuild: (markers) => rendered = markers,
        );

        await tester.pump(const Duration(milliseconds: 250));
        final mid = _byId(rendered, '1').position;
        expect(mid.latitude, greaterThan(start.latitude));
        expect(mid.latitude, lessThan(end.latitude));

        await _pumpUntilComplete(
          tester,
          implementation: implementation,
          duration: const Duration(milliseconds: 500),
        );
        expect(_byId(rendered, '1').position, end);
      });
    }
  });

  group('Animation-specific behavior', () {
    testWidgets('curve affects midpoint as expected', (tester) async {
      final initial = {_marker('1', 0, 0)};
      final target = {_marker('1', 10, 0)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        implementation: MotionImplementation.animation,
        duration: const Duration(milliseconds: 1000),
        animationCurve: Curves.easeIn,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: target,
        implementation: MotionImplementation.animation,
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
        implementation: MotionImplementation.animation,
        duration: const Duration(milliseconds: 3000),
        animationCurve: Curves.linear,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: p1,
        implementation: MotionImplementation.animation,
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
        implementation: MotionImplementation.animation,
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

  group('Timer-specific behavior', () {
    testWidgets('frameRate config is respected', (tester) async {
      final initial = {_marker('1', 0, 0)};
      final target = {_marker('1', 10, 0)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: initial,
        implementation: MotionImplementation.timer,
        duration: const Duration(milliseconds: 1000),
        frameRate: 1,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: target,
        implementation: MotionImplementation.timer,
        duration: const Duration(milliseconds: 1000),
        frameRate: 1,
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 600));
      expect(_byId(rendered, '1').position, const LatLng(0, 0));

      await tester.pump(const Duration(milliseconds: 500));
      expect(_byId(rendered, '1').position, const LatLng(10, 0));
    });

    testWidgets('runtime frameRate updates are applied', (tester) async {
      final p0 = {_marker('1', 0, 0)};
      final p1 = {_marker('1', 10, 0)};
      final p2 = {_marker('1', 20, 0)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: p0,
        implementation: MotionImplementation.timer,
        duration: const Duration(milliseconds: 1000),
        frameRate: 1,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: p1,
        implementation: MotionImplementation.timer,
        duration: const Duration(milliseconds: 1000),
        frameRate: 1,
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 600));
      expect(_byId(rendered, '1').position, const LatLng(0, 0));

      await _pumpMotion(
        tester,
        markers: p2,
        implementation: MotionImplementation.timer,
        duration: const Duration(milliseconds: 1000),
        frameRate: 120,
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(_byId(rendered, '1').position.latitude, greaterThan(0));
      expect(_byId(rendered, '1').position.latitude, lessThan(20));

      await _pumpUntilComplete(
        tester,
        implementation: MotionImplementation.timer,
        duration: const Duration(milliseconds: 1000),
        frameRate: 120,
      );
      expect(_byId(rendered, '1').position, const LatLng(20, 0));
    });

    testWidgets('new animation cancels old timer progression', (tester) async {
      final p0 = {_marker('1', 0, 0)};
      final p1 = {_marker('1', 10, 0)};
      final p2 = {_marker('1', 20, 0)};

      Set<Marker> rendered = {};

      await _pumpMotion(
        tester,
        markers: p0,
        implementation: MotionImplementation.timer,
        duration: const Duration(milliseconds: 1000),
        frameRate: 60,
        onBuild: (markers) => rendered = markers,
      );

      await _pumpMotion(
        tester,
        markers: p1,
        implementation: MotionImplementation.timer,
        duration: const Duration(milliseconds: 1000),
        frameRate: 60,
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 100));

      await _pumpMotion(
        tester,
        markers: p2,
        implementation: MotionImplementation.timer,
        duration: const Duration(milliseconds: 1000),
        frameRate: 60,
        onBuild: (markers) => rendered = markers,
      );

      await tester.pump(const Duration(milliseconds: 1200));
      expect(_byId(rendered, '1').position, const LatLng(20, 0));

      await tester.pump(const Duration(milliseconds: 300));
      expect(_byId(rendered, '1').position, const LatLng(20, 0));
      expect(tester.takeException(), isNull);
    });
  });
}
