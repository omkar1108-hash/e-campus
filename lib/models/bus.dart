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
  });

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
  }) => Bus(
    id: id,
    name: name ?? this.name,
    plate: plate ?? this.plate,
    driverUid: clearDriver ? null : (driverUid ?? this.driverUid),
    departments: departments ?? this.departments,
    active: active,
    lat: lat,
    lng: lng,
    updatedAt: updatedAt,
    tripStartedAt: tripStartedAt,
  );

  /// Fields administrators may write.
  Map<String, dynamic> configMap() => {
    'name': name,
    'plate': plate,
    'driverUid': driverUid,
    'departments': departments,
  };

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
  );
}
