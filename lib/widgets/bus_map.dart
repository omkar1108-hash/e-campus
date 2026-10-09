import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;
import 'package:latlong2/latlong.dart' as ll;

class BusMarker {
  const BusMarker({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
    required this.live,
  });

  final String id;
  final String label;
  final double lat;
  final double lng;

  /// False for a bus whose position is old (signal lost / trip ended).
  final bool live;
}

/// A route drawn on the map.
class MapLine {
  const MapLine({required this.id, required this.points});

  final String id;
  final List<(double, double)> points;
}

/// A start / end point of a route.
class MapStop {
  const MapStop({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
    this.isTarget = false,
  });

  final String id;
  final String label;
  final double lat;
  final double lng;

  /// The stop the bus is heading to right now.
  final bool isTarget;
}

/// Shows buses on a map.
///
/// Android and iOS use Google Maps. Windows, macOS, Linux and web use an
/// OpenStreetMap map, because the Google Maps plugin does not support them.
class BusMapView extends StatefulWidget {
  const BusMapView({
    super.key,
    required this.markers,
    this.focusId,
    this.lines = const [],
    this.stops = const [],
  });

  final List<BusMarker> markers;
  final List<MapLine> lines;
  final List<MapStop> stops;

  /// When set, the map centres on this bus.
  final String? focusId;

  /// Tests replace the map with a plain list.
  @visibleForTesting
  static bool debugListPlaceholder = false;

  /// True when the real map is replaced by a plain list (tests).
  static bool get isListPlaceholder => debugListPlaceholder;

  static bool get _useGoogle =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<BusMapView> createState() => _BusMapViewState();
}

class _BusMapViewState extends State<BusMapView> {
  g.GoogleMapController? _google;
  final _osm = osm.MapController();
  bool _osmReady = false;
  String? _lastCameraKey;

  // India, shown until a bus has a position.
  static const _defaultLat = 22.0;
  static const _defaultLng = 79.0;

  /// The camera only moves when the set of buses or the focus changes, so
  /// the user can pan around while positions keep updating.
  String get _cameraKey =>
      '${widget.focusId}|${(widget.markers.map((m) => m.id).toList()..sort()).join(',')}';

  @override
  void didUpdateWidget(BusMapView old) {
    super.didUpdateWidget(old);
    _moveCamera();
  }

  @override
  void dispose() {
    _google?.dispose();
    _osm.dispose();
    super.dispose();
  }

  void _moveCamera() {
    final markers = widget.markers;
    if (markers.isEmpty && widget.stops.length >= 2) {
      _fitStops();
      return;
    }
    if (markers.isEmpty || _cameraKey == _lastCameraKey) return;
    final focus = markers.where((m) => m.id == widget.focusId).firstOrNull;
    if (BusMapView._useGoogle) {
      final c = _google;
      if (c == null) return;
      _lastCameraKey = _cameraKey;
      if (focus != null || markers.length == 1) {
        final m = focus ?? markers.first;
        c.animateCamera(
          g.CameraUpdate.newLatLngZoom(g.LatLng(m.lat, m.lng), 15),
        );
      } else {
        c.animateCamera(
          g.CameraUpdate.newLatLngBounds(_googleBounds(markers), 64),
        );
      }
    } else {
      if (!_osmReady) return;
      _lastCameraKey = _cameraKey;
      if (focus != null || markers.length == 1) {
        final m = focus ?? markers.first;
        _osm.move(ll.LatLng(m.lat, m.lng), 15);
      } else {
        _osm.fitCamera(
          osm.CameraFit.bounds(
            bounds: osm.LatLngBounds.fromPoints([
              for (final m in markers) ll.LatLng(m.lat, m.lng),
            ]),
            padding: const EdgeInsets.all(64),
            maxZoom: 16,
          ),
        );
      }
    }
  }

  void _fitStops() {
    final key = 'stops|${widget.stops.map((s) => s.id).join(',')}';
    if (key == _lastCameraKey) return;
    final s = widget.stops;
    if (BusMapView._useGoogle) {
      final c = _google;
      if (c == null) return;
      _lastCameraKey = key;
      var minLat = s.first.lat, maxLat = s.first.lat;
      var minLng = s.first.lng, maxLng = s.first.lng;
      for (final p in s) {
        if (p.lat < minLat) minLat = p.lat;
        if (p.lat > maxLat) maxLat = p.lat;
        if (p.lng < minLng) minLng = p.lng;
        if (p.lng > maxLng) maxLng = p.lng;
      }
      c.animateCamera(
        g.CameraUpdate.newLatLngBounds(
          g.LatLngBounds(
            southwest: g.LatLng(minLat, minLng),
            northeast: g.LatLng(maxLat, maxLng),
          ),
          64,
        ),
      );
    } else {
      if (!_osmReady) return;
      _lastCameraKey = key;
      _osm.fitCamera(
        osm.CameraFit.bounds(
          bounds: osm.LatLngBounds.fromPoints([
            for (final p in s) ll.LatLng(p.lat, p.lng),
          ]),
          padding: const EdgeInsets.all(64),
          maxZoom: 16,
        ),
      );
    }
  }

  g.LatLngBounds _googleBounds(List<BusMarker> ms) {
    var minLat = ms.first.lat, maxLat = ms.first.lat;
    var minLng = ms.first.lng, maxLng = ms.first.lng;
    for (final m in ms) {
      if (m.lat < minLat) minLat = m.lat;
      if (m.lat > maxLat) maxLat = m.lat;
      if (m.lng < minLng) minLng = m.lng;
      if (m.lng > maxLng) maxLng = m.lng;
    }
    return g.LatLngBounds(
      southwest: g.LatLng(minLat, minLng),
      northeast: g.LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (BusMapView.debugListPlaceholder) {
      return ListView(
        children: [
          for (final s in widget.stops)
            ListTile(
              key: ValueKey('stop-${s.id}'),
              title: Text('${s.isTarget ? 'Heading to ' : ''}${s.label}'),
              subtitle: const Text('stop'),
            ),
          for (final l in widget.lines)
            ListTile(
              key: ValueKey('line-${l.id}'),
              title: Text('route with ${l.points.length} points'),
            ),
          for (final m in widget.markers)
            ListTile(
              key: ValueKey('marker-${m.id}'),
              title: Text(
                '${m.label} @ ${m.lat.toStringAsFixed(4)}, '
                '${m.lng.toStringAsFixed(4)}',
              ),
              subtitle: Text(m.live ? 'live' : 'last known'),
            ),
        ],
      );
    }
    return BusMapView._useGoogle ? _buildGoogle() : _buildOsm(context);
  }

  Widget _buildGoogle() {
    final first = widget.markers.firstOrNull;
    return g.GoogleMap(
      initialCameraPosition: g.CameraPosition(
        target: first == null
            ? const g.LatLng(_defaultLat, _defaultLng)
            : g.LatLng(first.lat, first.lng),
        zoom: first == null ? 4 : 15,
      ),
      onMapCreated: (c) {
        _google = c;
        _lastCameraKey = null;
        _moveCamera();
      },
      polylines: {
        for (final l in widget.lines)
          g.Polyline(
            polylineId: g.PolylineId(l.id),
            color: Colors.blue,
            width: 5,
            points: [for (final p in l.points) g.LatLng(p.$1, p.$2)],
          ),
      },
      markers: {
        for (final s in widget.stops)
          g.Marker(
            markerId: g.MarkerId('stop-${s.id}'),
            position: g.LatLng(s.lat, s.lng),
            infoWindow: g.InfoWindow(
              title: s.label,
              snippet: s.isTarget ? 'Next stop' : 'Stop',
            ),
            icon: g.BitmapDescriptor.defaultMarkerWithHue(
              s.isTarget
                  ? g.BitmapDescriptor.hueGreen
                  : g.BitmapDescriptor.hueRed,
            ),
          ),
        for (final m in widget.markers)
          g.Marker(
            markerId: g.MarkerId(m.id),
            position: g.LatLng(m.lat, m.lng),
            infoWindow: g.InfoWindow(
              title: m.label,
              snippet: m.live ? 'Live' : 'Last known position',
            ),
            icon: g.BitmapDescriptor.defaultMarkerWithHue(
              m.live
                  ? g.BitmapDescriptor.hueAzure
                  : g.BitmapDescriptor.hueOrange,
            ),
          ),
      },
    );
  }

  Widget _buildOsm(BuildContext context) {
    final first = widget.markers.firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    return osm.FlutterMap(
      mapController: _osm,
      options: osm.MapOptions(
        initialCenter: first == null
            ? const ll.LatLng(_defaultLat, _defaultLng)
            : ll.LatLng(first.lat, first.lng),
        initialZoom: first == null ? 4 : 15,
        onMapReady: () {
          _osmReady = true;
          _lastCameraKey = null;
          _moveCamera();
        },
      ),
      children: [
        osm.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.e_campus',
        ),
        osm.PolylineLayer(
          polylines: [
            for (final l in widget.lines)
              osm.Polyline(
                points: [for (final p in l.points) ll.LatLng(p.$1, p.$2)],
                strokeWidth: 5,
                color: Colors.blue.withValues(alpha: 0.8),
              ),
          ],
        ),
        osm.MarkerLayer(
          markers: [
            for (final s in widget.stops)
              osm.Marker(
                point: ll.LatLng(s.lat, s.lng),
                width: 120,
                height: 56,
                child: Column(
                  children: [
                    Icon(
                      Icons.place,
                      size: 30,
                      color: s.isTarget ? Colors.green : Colors.red,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final m in widget.markers)
              osm.Marker(
                point: ll.LatLng(m.lat, m.lng),
                width: 120,
                height: 64,
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_bus,
                      size: 32,
                      color: m.live ? scheme.primary : Colors.orange,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        m.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const osm.RichAttributionWidget(
          attributions: [
            osm.TextSourceAttribution('© OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}
