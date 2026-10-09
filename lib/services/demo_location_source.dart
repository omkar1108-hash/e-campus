import 'dart:async';

import 'location_source.dart';

/// Pretends to be a bus driving a loop, for demo mode and tests.
class DemoLocationSource implements LocationSource {
  DemoLocationSource({this.interval = const Duration(seconds: 3)});

  final Duration interval;

  // A small loop of points near Visakhapatnam.
  static const route = <GeoFix>[
    GeoFix(17.7231, 83.3013),
    GeoFix(17.7260, 83.3055),
    GeoFix(17.7295, 83.3098),
    GeoFix(17.7330, 83.3140),
    GeoFix(17.7300, 83.3190),
    GeoFix(17.7260, 83.3150),
    GeoFix(17.7235, 83.3070),
  ];

  @override
  Future<GeoFix> current() async => route.first;

  @override
  Stream<GeoFix> track() async* {
    var i = 0;
    while (true) {
      await Future<void>.delayed(interval);
      i = (i + 1) % route.length;
      yield route[i];
    }
  }
}
