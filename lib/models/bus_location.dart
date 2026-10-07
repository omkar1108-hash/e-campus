class BusLocation {
  const BusLocation({
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'lat': latitude,
    'lng': longitude,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory BusLocation.fromMap(Map<String, dynamic> map) => BusLocation(
    latitude: (map['lat'] as num).toDouble(),
    longitude: (map['lng'] as num).toDouble(),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (map['updatedAt'] ?? 0) as int,
    ),
  );
}
