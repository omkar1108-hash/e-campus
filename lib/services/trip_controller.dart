import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend.dart';
import 'location_source.dart';

/// Runs a bus driver's trip: publishes GPS positions while a trip is on.
///
/// It lives above the screens, so tracking keeps going while the driver
/// moves between menu entries.
class TripController extends ChangeNotifier {
  TripController(this.backend, this.location);

  final Backend backend;
  final LocationSource location;

  StreamSubscription<GeoFix>? _sub;
  String? _busId;
  bool _busy = false;
  String? _error;

  bool get busy => _busy;
  String? get error => _error;

  /// Whether this phone is currently sending positions for [busId].
  bool isTracking(String busId) => _sub != null && _busId == busId;

  Future<void> start(String busId) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final fix = await location.current();
      await backend.startTrip(busId, fix.lat, fix.lng);
      // Cancelling takes effect immediately; there is nothing to wait for.
      unawaited(_sub?.cancel());
      _busId = busId;
      _sub = location.track().listen(
        (f) async {
          try {
            await backend.updateTripLocation(busId, f.lat, f.lng);
          } catch (_) {
            _error = 'Could not send the bus position. Check your internet.';
            notifyListeners();
          }
        },
        onError: (Object e) {
          _error = e is LocationException ? e.message : 'GPS error: $e';
          notifyListeners();
        },
      );
    } on LocationException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Could not start the trip: $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> end(String busId) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      unawaited(_sub?.cancel());
      _sub = null;
      _busId = null;
      await backend.endTrip(busId);
    } catch (e) {
      _error = 'Could not end the trip: $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Called on sign out so a trip is never left running.
  Future<void> stopIfRunning() async {
    final id = _busId;
    if (id != null) await end(id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
