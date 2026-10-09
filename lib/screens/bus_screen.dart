import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/bus.dart';
import '../services/backend.dart';
import '../services/trip_controller.dart';
import '../utils/bus_status.dart';
import '../utils/rbac.dart';
import '../widgets/bus_map.dart';
import '../widgets/bus_route_info.dart';

List<BusMarker> _markers(List<Bus> buses, DateTime now) => [
  for (final b in buses)
    if (b.hasPosition)
      BusMarker(
        id: b.id,
        label: b.name,
        lat: b.lat!,
        lng: b.lng!,
        live: b.isLive(now),
      ),
];

/// Drivers get trip controls; everyone else gets the tracking map.
class BusScreen extends StatelessWidget {
  const BusScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) => Rbac.canShareBusLocation(user)
      ? _DriverView(user: user)
      : _TrackView(user: user);
}

/// Re-evaluates "live" every few seconds even if no new data arrives.
mixin _Ticking<T extends StatefulWidget> on State<T> {
  Timer? _tick;
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

class _TrackView extends StatefulWidget {
  const _TrackView({required this.user});

  final AppUser user;

  @override
  State<_TrackView> createState() => _TrackViewState();
}

class _TrackViewState extends State<_TrackView> with _Ticking {
  String? _focusId;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return StreamBuilder<List<Bus>>(
      stream: backend.watchBuses(widget.user),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load buses: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final buses = snap.data!;
        final markers = _markers(buses, now);
        return Column(
          children: [
            Expanded(
              flex: 3,
              child: RoutedBusMap(
                buses: buses,
                markers: markers,
                focusId: _focusId,
              ),
            ),
            Expanded(
              flex: 2,
              child: buses.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No buses are assigned to your department yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: buses.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          final r = RoutedBusMap.routed(buses, _focusId);
                          return r == null
                              ? const SizedBox.shrink()
                              : BusRouteInfo(bus: r, now: now);
                        }
                        final b = buses[i - 1];
                        final live = b.isLive(now);
                        return ListTile(
                          selected: _focusId == b.id,
                          leading: Icon(
                            Icons.directions_bus,
                            color: live ? Colors.green : null,
                          ),
                          title: Text(b.name),
                          subtitle: Text(
                            '${b.plate}\n${busStatus(b, now)}'
                            '${b.hasRoute ? '\n${b.legLabel}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: b.hasPosition
                              ? const Icon(Icons.my_location)
                              : null,
                          onTap: b.hasPosition
                              ? () => setState(() => _focusId = b.id)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DriverView extends StatefulWidget {
  const _DriverView({required this.user});

  final AppUser user;

  @override
  State<_DriverView> createState() => _DriverViewState();
}

class _DriverViewState extends State<_DriverView> with _Ticking {
  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final trips = context.watch<TripController>();
    return StreamBuilder<List<Bus>>(
      stream: backend.watchBuses(widget.user),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load your bus: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bus = snap.data!.firstOrNull;
        if (bus == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No bus has been assigned to you yet.\n'
                'Ask the administration to assign one.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final sharing = trips.isTracking(bus.id);
        return Column(
          children: [
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      bus.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${bus.plate} · ${bus.departments.join(', ')}'),
                    const SizedBox(height: 8),
                    Text(
                      sharing
                          ? 'Trip in progress - sharing your location'
                          : bus.active
                          ? 'Trip is marked active, but this phone is not '
                                'sharing its location.'
                          : 'No trip running',
                    ),
                    if (trips.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          trips.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (bus.hasRoute && bus.active)
                      Text(
                        'Now heading to ${bus.legTo!.name}',
                        key: const ValueKey('heading-to'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    const SizedBox(height: 12),
                    if (!sharing)
                      FilledButton.icon(
                        onPressed: trips.busy
                            ? null
                            : () => trips.start(bus.id, bus: bus),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(bus.active ? 'Resume trip' : 'Start trip'),
                      ),
                    if (sharing || bus.active) ...[
                      if (!sharing) const SizedBox(height: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: trips.busy ? null : () => trips.end(bus.id),
                        icon: const Icon(Icons.stop),
                        label: const Text('End trip'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            BusRouteInfo(bus: bus, now: now),
            Expanded(
              child: RoutedBusMap(
                buses: [bus],
                markers: _markers([bus], now),
                focusId: bus.id,
              ),
            ),
          ],
        );
      },
    );
  }
}
