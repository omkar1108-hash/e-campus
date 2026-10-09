import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GeoFix {
  const GeoFix(this.lat, this.lng);
  final double lat;
  final double lng;
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Where the driver's GPS positions come from. The real implementation uses
/// the phone's GPS; tests and the demo provide a fake.
abstract class LocationSource {
  /// Asks for permission if needed and returns the current position.
  Future<GeoFix> current();

  /// Continuous positions while a trip runs.
  Stream<GeoFix> track();
}

class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  Future<void> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Turn on location services first.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission denied. Allow location for E-Campus in Settings.',
      );
    }
  }

  @override
  Future<GeoFix> current() async {
    await _ensurePermission();
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return GeoFix(p.latitude, p.longitude);
  }

  @override
  Stream<GeoFix> track() {
    // On Android a foreground notification keeps tracking alive when the
    // screen is off or the app is in the background.
    final LocationSettings settings =
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'E-Campus bus trip',
              notificationText: 'Sharing the bus location with students.',
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map((p) => GeoFix(p.latitude, p.longitude));
  }
}
