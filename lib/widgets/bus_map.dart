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

/// Shows buses on a map.
///
/// Android and iOS use Google Maps. Windows, macOS, Linux and web use an
/// OpenStreetMap map, because the Google Maps plugin does not support them.
class BusMapView extends StatefulWidget {
  const BusMapView({super.key, required this.markers, this.focusId});

  final List<BusMarker> markers;

  /// When set, the map centres on this bus.
  final String? focusId;

  /// Tests replace the map with a plain list.
  @visibleForTesting
  static bool debugListPlaceholder = false;

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
      markers: {
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
        osm.MarkerLayer(
          markers: [
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
