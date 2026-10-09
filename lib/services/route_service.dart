import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bus.dart';

/// A driving route between two places.
class RouteInfo {
  const RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.estimated = false,
  });

  /// (lat, lng) pairs along the road.
  final List<(double, double)> points;
  final double distanceMeters;
  final double durationSeconds;

  /// True when no road route could be fetched and the figures are a
  /// straight-line guess.
  final bool estimated;

  String get distanceText => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  String get durationText =>
      formatDuration(Duration(seconds: durationSeconds.round()));
}

/// "25 min", "1 h 5 min".
String formatDuration(Duration d) {
  final mins = (d.inSeconds / 60).ceil();
  if (mins < 1) return 'under a minute';
  if (mins < 60) return '$mins min';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

abstract class RouteService {
  Future<RouteInfo> route(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  );
}

/// A straight line at a typical city bus speed. Used when the road service
/// cannot be reached, and in tests and demo mode.
class EstimateRouteService implements RouteService {
  const EstimateRouteService();

  /// Road distance is longer than the straight line.
  static const detour = 1.3;

  /// Average speed in km/h.
  static const speedKmh = 30.0;

  @override
  Future<RouteInfo> route(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) async {
    final d = distanceMeters(fromLat, fromLng, toLat, toLng) * detour;
    return RouteInfo(
      points: [(fromLat, fromLng), (toLat, toLng)],
      distanceMeters: d,
      durationSeconds: d / (speedKmh * 1000 / 3600),
      estimated: true,
    );
  }
}

/// Road routes and travel times from the free OSRM demo server
/// (OpenStreetMap data). Falls back to [EstimateRouteService].
class OsrmRouteService implements RouteService {
  OsrmRouteService({
    http.Client? client,
    this.baseUrl = 'https://router.project-osrm.org',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  @override
  Future<RouteInfo> route(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat'
        '?overview=full&geometries=geojson',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final r = (json['routes'] as List).first as Map<String, dynamic>;
      final coords = (r['geometry']['coordinates'] as List)
          .map((c) => ((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      return RouteInfo(
        points: coords,
        distanceMeters: (r['distance'] as num).toDouble(),
        durationSeconds: (r['duration'] as num).toDouble(),
      );
    } catch (_) {
      return const EstimateRouteService().route(fromLat, fromLng, toLat, toLng);
    }
  }
}

/// Remembers routes already fetched so the map and the cards do not ask the
/// server again and again. Positions are rounded to ~100 m for the key.
class RouteCache {
  RouteCache(this.service);

  final RouteService service;
  final Map<String, Future<RouteInfo>> _cache = {};

  static String _k(double a) => a.toStringAsFixed(3);

  Future<RouteInfo> get(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) => _cache.putIfAbsent(
    '${_k(fromLat)},${_k(fromLng)}>${_k(toLat)},${_k(toLng)}',
    () => service.route(fromLat, fromLng, toLat, toLng),
  );

  /// The planned route of a bus's current leg, or null with no route set.
  Future<RouteInfo>? planned(Bus bus) {
    if (!bus.hasRoute) return null;
    final a = bus.legFrom!, b = bus.legTo!;
    return get(a.lat, a.lng, b.lat, b.lng);
  }

  /// Time left from the bus's current position to the end of its leg.
  Future<RouteInfo>? remaining(Bus bus) {
    if (!bus.hasRoute || !bus.hasPosition) return null;
    final b = bus.legTo!;
    return get(bus.lat!, bus.lng!, b.lat, b.lng);
  }
}
