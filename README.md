# Marker Motion

Animate markers in Google maps from one position to another smoothly using this flutter package.

[![Pub Version](https://img.shields.io/pub/v/marker_motion)](https://pub.dev/packages/marker_motion)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Features

- Automatically animate marker positions passed into the MarkerMotion widget that share a marker id
- Customize the animation duration
- Customize the animation curve

## Usage

Using MarkerMotion is as simple as wrapping your Google Maps widget with the `MarkerMotion` widget:

```dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_motion/marker_motion.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // The set of markers that you want to animate between multiple positions
  Set<Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Animated Map Markers')),
      body: MarkerMotion(
        // Pass your markers to animate them
        markers: _markers,
        // Configure the widget using the config object
        config: MarkerMotionConfig(
          // Control the animation duration (default: 3200ms)
          duration: Duration(milliseconds: 5100),
        ),
        // Builder receives the animated markers that you can then pass to your
        // GoogleMap to animate them
        builder: (markers) {
            GoogleMap(
              markers: markers,
            );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateMarkerPositions,
        child: Icon(Icons.refresh),
      ),
    );
  }

  void _updateMarkerPositions() {
    // Update the marker positions and watch them smoothly animate on your GoogleMap widget
    setState(() {
      _markers = {
        Marker(
          markerId: MarkerId('marker1'),
          position: LatLng(
            37.42796 + (Random().nextDouble() - 0.5) * 0.01,
            -122.08574 + (Random().nextDouble() - 0.5) * 0.01,
          ),
        ),
        // Add more markers here if you want
      };
    });
  }
}
```

## How It Works

The `MarkerMotion` widget keeps track of marker positions between state changes. When a marker's
position changes, it smoothly animates from the old position to the new position using an
animation controller.

## Customization

Customizing the `MarkerMotion` widget is as simple as passing a `MarkerMotionConfig` object
as a config to the constructor.

```dart
MarkerMotion(
  markers: _markers,
  config: MarkerMotionConfig(),
)
```

The following config options are currently supported:

| name | type | default | options | description |
|:-----|:-----|:--------|:--------|:------------|
| duration | Duration | Duration(milliseconds: 3200) | Any duration | The duration that your animation should run for. |
| animationCurve | Curve | Curves.linear | Any animation curve | The animation curve to use when animating your markers. |

## Contributing

Contributions are welcome! Please feel free to submit a pull request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feat/add-marker-rotations`)
3. Commit your changes (`git commit -m 'Animate rotations for markers'`)
4. Push to the branch (`git push origin feature/add-marker-rotations`)
5. Open a pull request

## Features to consider working on

I might be working on some of these at the moment, so let me know if you plan to tackle one of them so we can coordinate.

- Animating marker's rotation
- Animating the markers along a given polyline even if the position is off by a bit
- Add a minimum distance that new positions must be greater than before triggering marker animations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.