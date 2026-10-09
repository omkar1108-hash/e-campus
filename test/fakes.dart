import 'dart:async';

import 'package:e_campus/services/location_source.dart';

/// A GPS the test drives by hand.
class FakeLocation implements LocationSource {
  final controller = StreamController<GeoFix>.broadcast();
  Object? failWith;

  @override
  Future<GeoFix> current() async {
    if (failWith != null) throw failWith!;
    return const GeoFix(10, 20);
  }

  @override
  Stream<GeoFix> track() => controller.stream;
}
