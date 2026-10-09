import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import '../models/bus.dart';
import '../services/location_source.dart';
import 'bus_map.dart';

/// Fields for one route point: a name, latitude and longitude, with
/// buttons to pick the spot on a map or use the phone's current position.
class StopFieldController {
  StopFieldController([BusStop? stop])
    : name = TextEditingController(text: stop?.name ?? ''),
      lat = TextEditingController(text: stop?.lat.toString() ?? ''),
      lng = TextEditingController(text: stop?.lng.toString() ?? '');

  final TextEditingController name;
  final TextEditingController lat;
  final TextEditingController lng;

  bool get isEmpty =>
      name.text.trim().isEmpty &&
      lat.text.trim().isEmpty &&
      lng.text.trim().isEmpty;

  /// Null when empty or invalid (see [validate]).
  BusStop? get stop {
    final la = double.tryParse(lat.text.trim());
    final ln = double.tryParse(lng.text.trim());
    if (la == null || ln == null || name.text.trim().isEmpty) return null;
    return BusStop(name: name.text.trim(), lat: la, lng: ln);
  }

  void dispose() {
    name.dispose();
    lat.dispose();
    lng.dispose();
  }
}

class StopField extends StatefulWidget {
  const StopField({super.key, required this.title, required this.controller});

  final String title;
  final StopFieldController controller;

  @override
  State<StopField> createState() => _StopFieldState();
}

class _StopFieldState extends State<StopField> {
  StopFieldController get c => widget.controller;

  String? _coord(String? v, double limit) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return c.isEmpty ? null : 'Required';
    final d = double.tryParse(t);
    if (d == null || d.abs() > limit) return 'Invalid';
    return null;
  }

  Future<void> _pickOnMap() async {
    final start = c.stop;
    final result = await showDialog<ll.LatLng>(
      context: context,
      builder: (_) => _MapPickerDialog(
        initial: start == null ? null : ll.LatLng(start.lat, start.lng),
      ),
    );
    if (result == null) return;
    setState(() {
      c.lat.text = result.latitude.toStringAsFixed(6);
      c.lng.text = result.longitude.toStringAsFixed(6);
    });
  }

  Future<void> _useMyLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fix = await context.read<LocationSource>().current();
      setState(() {
        c.lat.text = fix.lat.toStringAsFixed(6);
        c.lng.text = fix.lng.toStringAsFixed(6);
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        TextFormField(
          controller: c.name,
          decoration: const InputDecoration(labelText: 'Place name'),
          validator: (v) =>
              (v ?? '').trim().isEmpty && !c.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.lat,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Latitude'),
                validator: (v) => _coord(v, 90),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: c.lng,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Longitude'),
                validator: (v) => _coord(v, 180),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            if (!BusMapView.isListPlaceholder)
              TextButton.icon(
                onPressed: _pickOnMap,
                icon: const Icon(Icons.map),
                label: const Text('Pick on map'),
              ),
            TextButton.icon(
              onPressed: _useMyLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Use my location'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MapPickerDialog extends StatefulWidget {
  const _MapPickerDialog({this.initial});

  final ll.LatLng? initial;

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late ll.LatLng? _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tap the place on the map'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: osm.FlutterMap(
          options: osm.MapOptions(
            initialCenter: widget.initial ?? const ll.LatLng(22.0, 79.0),
            initialZoom: widget.initial == null ? 4 : 14,
            onTap: (_, p) => setState(() => _picked = p),
          ),
          children: [
            osm.TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.e_campus',
            ),
            if (_picked != null)
              osm.MarkerLayer(
                markers: [
                  osm.Marker(
                    point: _picked!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.place, color: Colors.red, size: 36),
                  ),
                ],
              ),
            const osm.RichAttributionWidget(
              attributions: [
                osm.TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _picked == null
              ? null
              : () => Navigator.pop(context, _picked),
          child: const Text('Use this place'),
        ),
      ],
    );
  }
}
