import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/bus_location.dart';
import '../services/backend.dart';
import '../utils/rbac.dart';

/// Live college-bus position on Google Maps. Everyone can watch; the admin
/// (bus driver account) can publish the phone's GPS position.
class BusScreen extends StatefulWidget {
  const BusScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  GoogleMapController? _map;
  StreamSubscription<Position>? _gps;
  bool get _sharing => _gps != null;

  @override
  void dispose() {
    _gps?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _toggleSharing() async {
    if (_sharing) {
      await _gps?.cancel();
      setState(() => _gps = null);
      return;
    }
    final backend = context.read<Backend>();
    final messenger = ScaffoldMessenger.of(context);

    if (!await Geolocator.isLocationServiceEnabled()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Turn on location services first')),
      );
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _gps =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            (p) => backend.updateBus(
              BusLocation(
                latitude: p.latitude,
                longitude: p.longitude,
                updatedAt: DateTime.now(),
              ),
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final canShare = Rbac.canShareBusLocation(widget.user);
    return StreamBuilder<BusLocation?>(
      stream: backend.watchBus(),
      builder: (context, snap) {
        final bus = snap.data;
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (bus == null) {
          return const Center(child: Text('Bus location not available yet'));
        }
        final pos = LatLng(bus.latitude, bus.longitude);
        _map?.animateCamera(CameraUpdate.newLatLng(pos));
        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: pos, zoom: 15),
              onMapCreated: (c) => _map = c,
              markers: {
                Marker(
                  markerId: const MarkerId('bus'),
                  position: pos,
                  infoWindow: const InfoWindow(title: 'College Bus'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  ),
                ),
              },
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_bus),
                  title: const Text('College Bus'),
                  subtitle: Text(
                    '${bus.latitude.toStringAsFixed(5)}, '
                    '${bus.longitude.toStringAsFixed(5)}\n'
                    'Updated ${DateFormat.jms().format(bus.updatedAt)}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
            if (canShare)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: FilledButton.icon(
                  onPressed: _toggleSharing,
                  icon: Icon(_sharing ? Icons.stop : Icons.share_location),
                  label: Text(
                    _sharing
                        ? 'Stop sharing location'
                        : 'Share my location as bus',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
