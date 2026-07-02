import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_motion/marker_motion.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marker Motion Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Random _random = Random();

  // Starting position
  final LatLng _center = const LatLng(37.42796, -122.08574);

  // Set of markers
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // Initialize with some markers
    _markers = {
      _createMarker(_getRandomId(), _center),
      _createMarker(
        _getRandomId(),
        LatLng(_center.latitude + 0.005, _center.longitude + 0.005),
      ),
      _createMarker(
        _getRandomId(),
        LatLng(_center.latitude - 0.005, _center.longitude - 0.005),
      ),
    };
  }

  Marker _createMarker(String id, LatLng position) {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(title: 'Marker $id'),
    );
  }

  String _getRandomId() {
    return List.generate(12, (_) => _random.nextInt(10)).join();
  }

  void _moveMarkers() {
    setState(() {
      // Create new set of markers with randomized positions
      _markers =
          _markers.map((marker) {
            // Move marker by random amount (max ±0.01 degrees)
            final newPosition = LatLng(
              marker.position.latitude + (_random.nextDouble() - 0.5) * 0.01,
              marker.position.longitude + (_random.nextDouble() - 0.5) * 0.01,
            );

            return _createMarker(marker.markerId.value, newPosition);
          }).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Marker Motion Demo'),
      ),
      body: MarkerMotion(
        // Pass current markers
        markers: _markers,
        // Pass animation options to widget using config object
        config: const MarkerMotionConfig(
          // Set animation duration (adjust as needed)
          duration: Duration(milliseconds: 4300),
        ),
        // Builder receives animated markers
        builder: (animatedMarkers) {
          return GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 14),
            markers: animatedMarkers,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
          );
        },
      ),
      floatingActionButton: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _moveMarkers,
            tooltip: 'Move Markers',
            child: const Icon(Icons.shuffle),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_markers.length > 1) ...[
                FloatingActionButton(
                  key: Key('remove_button'),
                  onPressed: () {
                    if (_markers.length == 1) return;

                    setState(() {
                      // Remove a random marker
                      final marker = _markers.elementAt(
                        _random.nextInt(_markers.length),
                      );

                      _markers.remove(marker);
                    });
                  },
                  tooltip: 'Remove Marker',
                  child: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 16),
              ],
              FloatingActionButton(
                key: Key('add_button'),
                onPressed: () {
                  setState(() {
                    // Add a new marker
                    final id = _getRandomId();
                    final newPosition = LatLng(
                      _center.latitude + (_random.nextDouble() - 0.5) * 0.02,
                      _center.longitude + (_random.nextDouble() - 0.5) * 0.02,
                    );
                    _markers.add(_createMarker(id, newPosition));
                  });
                },
                tooltip: 'Add Marker',
                child: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
