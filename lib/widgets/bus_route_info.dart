import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bus.dart';
import '../services/route_service.dart';
import 'bus_map.dart';

/// The bus map with its current leg drawn on it (the focused bus, or the
/// only bus shown).
class RoutedBusMap extends StatelessWidget {
  const RoutedBusMap({
    super.key,
    required this.buses,
    required this.markers,
    this.focusId,
  });

  final List<Bus> buses;
  final List<BusMarker> markers;
  final String? focusId;

  /// The bus whose route is shown.
  static Bus? routed(List<Bus> buses, String? focusId) {
    final withRoute = buses.where((b) => b.hasRoute).toList();
    if (focusId != null) {
      final f = withRoute.where((b) => b.id == focusId).firstOrNull;
      if (f != null) return f;
    }
    return buses.length == 1 ? withRoute.firstOrNull : null;
  }

  @override
  Widget build(BuildContext context) {
    final bus = routed(buses, focusId);
    if (bus == null) return BusMapView(markers: markers, focusId: focusId);
    final cache = context.read<RouteCache>();
    final from = bus.legFrom!, to = bus.legTo!;
    return FutureBuilder<RouteInfo>(
      future: cache.planned(bus),
      builder: (context, snap) => BusMapView(
        markers: markers,
        focusId: focusId,
        stops: [
          MapStop(
            id: 'from-${bus.id}',
            label: from.name,
            lat: from.lat,
            lng: from.lng,
          ),
          MapStop(
            id: 'to-${bus.id}',
            label: to.name,
            lat: to.lat,
            lng: to.lng,
            isTarget: true,
          ),
        ],
        lines: [
          if (snap.hasData)
            MapLine(id: 'route-${bus.id}', points: snap.data!.points),
        ],
      ),
    );
  }
}

/// Route, distance, travel time and (while the bus is running) the time
/// left to the next stop.
class BusRouteInfo extends StatelessWidget {
  const BusRouteInfo({super.key, required this.bus, required this.now});

  final Bus bus;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (!bus.hasRoute) return const SizedBox.shrink();
    final cache = context.read<RouteCache>();
    final theme = Theme.of(context);
    final leg = bus.leg == Bus.returning ? 'Return' : 'Outbound';
    return Card(
      key: ValueKey('route-info-${bus.id}'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$leg: ${bus.legLabel}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FutureBuilder<RouteInfo>(
              future: cache.planned(bus),
              builder: (context, snap) {
                if (!snap.hasData) return const Text('Calculating route…');
                final r = snap.data!;
                return Text(
                  'Trip: ${r.distanceText}, about ${r.durationText}'
                  '${r.estimated ? ' (estimate)' : ''}',
                  key: const ValueKey('route-total'),
                );
              },
            ),
            if (bus.isLive(now))
              FutureBuilder<RouteInfo>(
                future: cache.remaining(bus),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final r = snap.data!;
                  return Text(
                    'Reaches ${bus.legTo!.name} in about ${r.durationText} '
                    '(${r.distanceText} to go)',
                    key: const ValueKey('route-eta'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            Text(
              'At the end of each leg the bus turns back automatically.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
