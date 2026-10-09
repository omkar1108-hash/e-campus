import 'dart:math' as math;

/// A named place on a bus route (start or end point).
class BusStop {
  const BusStop({required this.name, required this.lat, required this.lng});

  final String name;
  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is BusStop &&
      other.name == name &&
      other.lat == lat &&
      other.lng == lng;

  @override
  int get hashCode => Object.hash(name, lat, lng);
}

/// Straight-line distance in metres between two coordinates.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

/// A college bus. Configuration (name, plate, driver, departments) is set by
/// administrators; the live fields are written only by the assigned driver.
class Bus {
  const Bus({
    required this.id,
    required this.name,
    required this.plate,
    this.driverUid,
    this.departments = const [],
    this.active = false,
    this.lat,
    this.lng,
    this.updatedAt,
    this.tripStartedAt,
    this.start,
    this.end,
    this.leg = outbound,
  });

  static const outbound = 'outbound';
  static const returning = 'return';

  /// How close (metres) the bus must get to a stop to count as arrived.
  static const arrivalRadius = 120.0;

  final String id;
  final String name;
  final String plate;

  /// Uid of the bus driver account assigned to this bus.
  final String? driverUid;

  /// Departments whose students and staff may track this bus.
  final List<String> departments;

  /// True while the driver has a trip running.
  final bool active;
  final double? lat;
  final double? lng;
  final DateTime? updatedAt;
  final DateTime? tripStartedAt;

  /// Route set by administration: the bus runs start -> end (outbound) and
  /// then back end -> start (return), switching automatically on arrival.
  final BusStop? start;
  final BusStop? end;

  /// [outbound] or [returning]; changed by the driver's phone on arrival.
  final String leg;

  bool get hasRoute => start != null && end != null;

  /// Where the current leg begins and ends.
  BusStop? get legFrom => leg == returning ? end : start;
  BusStop? get legTo => leg == returning ? start : end;

  /// "North Gate to Campus" for the current leg.
  String get legLabel =>
      hasRoute ? '${legFrom!.name} to ${legTo!.name}' : 'No route set';

  /// The leg to take after arriving at [legTo].
  String get nextLeg => leg == returning ? outbound : returning;

  /// Automatic leg switching needs the two stops to be well apart.
  bool get canAutoSwitch =>
      hasRoute &&
      distanceMeters(start!.lat, start!.lng, end!.lat, end!.lng) >
          arrivalRadius * 3;

  /// A trip counts as live only while position updates keep arriving.
  static const staleAfter = Duration(seconds: 90);

  bool get hasPosition => lat != null && lng != null;

  bool isLive(DateTime now) =>
      active &&
      hasPosition &&
      updatedAt != null &&
      now.difference(updatedAt!) < staleAfter;

  Bus copyWith({
    String? name,
    String? plate,
    String? driverUid,
    bool clearDriver = false,
    List<String>? departments,
    BusStop? start,
    BusStop? end,
    bool clearRoute = false,
    bool? active,
    double? lat,
    double? lng,
    DateTime? updatedAt,
    DateTime? tripStartedAt,
    String? leg,
  }) => Bus(
    id: id,
    name: name ?? this.name,
    plate: plate ?? this.plate,
    driverUid: clearDriver ? null : (driverUid ?? this.driverUid),
    departments: departments ?? this.departments,
    active: active ?? this.active,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    updatedAt: updatedAt ?? this.updatedAt,
    tripStartedAt: tripStartedAt ?? this.tripStartedAt,
    start: clearRoute ? null : (start ?? this.start),
    end: clearRoute ? null : (end ?? this.end),
    leg: leg ?? this.leg,
  );

  /// Fields administrators may write.
  Map<String, dynamic> configMap() => {
    'name': name,
    'plate': plate,
    'driverUid': driverUid,
    'departments': departments,
    'startName': start?.name,
    'startLat': start?.lat,
    'startLng': start?.lng,
    'endName': end?.name,
    'endLat': end?.lat,
    'endLng': end?.lng,
  };

  static BusStop? _stop(Map<String, dynamic> m, String key) {
    final lat = (m['${key}Lat'] as num?)?.toDouble();
    final lng = (m['${key}Lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return BusStop(name: (m['${key}Name'] ?? '') as String, lat: lat, lng: lng);
  }

  factory Bus.fromMap(String id, Map<String, dynamic> map) => Bus(
    id: id,
    name: (map['name'] ?? '') as String,
    plate: (map['plate'] ?? '') as String,
    driverUid: map['driverUid'] as String?,
    departments: List<String>.from((map['departments'] ?? const []) as List),
    active: (map['active'] ?? false) as bool,
    lat: (map['lat'] as num?)?.toDouble(),
    lng: (map['lng'] as num?)?.toDouble(),
    updatedAt: map['updatedAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    tripStartedAt: map['tripStartedAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['tripStartedAt'] as int),
    start: _stop(map, 'start'),
    end: _stop(map, 'end'),
    leg: (map['leg'] ?? outbound) as String,
  );
}
