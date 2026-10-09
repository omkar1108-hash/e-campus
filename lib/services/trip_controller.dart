import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/bus.dart';
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
  Bus? _bus;
  String _leg = Bus.outbound;
  bool _busy = false;
  String? _error;

  bool get busy => _busy;
  String? get error => _error;

  /// Whether this phone is currently sending positions for [busId].
  bool isTracking(String busId) => _sub != null && _busId == busId;

  /// Which leg of its route the bus is on (outbound / return).
  String get leg => _leg;

  /// [bus] lets the trip switch to the return route on its own when the
  /// phone reaches the end of a leg.
  Future<void> start(String busId, {Bus? bus}) async {
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
      _bus = bus;
      _leg = Bus.outbound;
      _sub = location.track().listen(
        (f) async {
          try {
            await backend.updateTripLocation(busId, f.lat, f.lng);
            await _checkArrival(busId, f);
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

  /// When the bus reaches the end of its leg, start the way back.
  Future<void> _checkArrival(String busId, GeoFix f) async {
    final bus = _bus;
    if (bus == null || !bus.canAutoSwitch) return;
    final to = _leg == Bus.returning ? bus.start! : bus.end!;
    if (distanceMeters(f.lat, f.lng, to.lat, to.lng) > Bus.arrivalRadius) {
      return;
    }
    final next = _leg == Bus.returning ? Bus.outbound : Bus.returning;
    _leg = next;
    await backend.setBusLeg(busId, next);
    notifyListeners();
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
      _bus = null;
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
