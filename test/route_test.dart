import 'dart:convert';

import 'package:e_campus/models/app_user.dart';
import 'package:e_campus/models/bus.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:e_campus/services/location_source.dart';
import 'package:e_campus/services/route_service.dart';
import 'package:e_campus/services/trip_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';
import 'helpers.dart';

const _a = BusStop(name: 'North Gate', lat: 17.7231, lng: 83.3013);
const _b = BusStop(name: 'Campus', lat: 17.7330, lng: 83.3140);

Bus _bus({String leg = Bus.outbound, BusStop? end = _b}) =>
    Bus(id: 'b', name: 'Bus', plate: 'P', start: _a, end: end, leg: leg);

class _CountingService implements RouteService {
  int calls = 0;
  @override
  Future<RouteInfo> route(double a, double b, double c, double d) async {
    calls++;
    return RouteInfo(
      points: [(a, b), (c, d)],
      distanceMeters: 1000,
      durationSeconds: 120,
    );
  }
}

void main() {
  group('bus route model', () {
    test('legs run start to end, then back', () {
      final out = _bus();
      expect(out.legFrom, _a);
      expect(out.legTo, _b);
      expect(out.legLabel, 'North Gate to Campus');
      expect(out.nextLeg, Bus.returning);
      final back = _bus(leg: Bus.returning);
      expect(back.legFrom, _b);
      expect(back.legTo, _a);
      expect(back.legLabel, 'Campus to North Gate');
      expect(back.nextLeg, Bus.outbound);
    });

    test('no route means no legs', () {
      final b = _bus(end: null);
      expect(b.hasRoute, isFalse);
      expect(b.legLabel, 'No route set');
      expect(b.canAutoSwitch, isFalse);
    });

    test('stops too close together never switch automatically', () {
      const near = BusStop(name: 'Near', lat: 17.72311, lng: 83.30131);
      expect(_bus(end: near).canAutoSwitch, isFalse);
      expect(_bus().canAutoSwitch, isTrue);
    });

    test('route survives the stored form', () {
      final b = Bus.fromMap('x', {
        ..._bus().configMap(),
        'active': true,
        'leg': 'return',
      });
      expect(b.start, _a);
      expect(b.end, _b);
      expect(b.leg, Bus.returning);
      expect(Bus.fromMap('y', {'name': 'n', 'plate': 'p'}).hasRoute, isFalse);
    });

    test('distance between two points', () {
      expect(distanceMeters(0, 0, 1, 0), closeTo(111195, 300));
      expect(distanceMeters(10, 10, 10, 10), 0);
    });
  });

  group('route service', () {
    test('durations read naturally', () {
      expect(formatDuration(const Duration(seconds: 20)), '1 min');
      expect(formatDuration(const Duration(minutes: 25)), '25 min');
      expect(formatDuration(const Duration(minutes: 60)), '1 h');
      expect(formatDuration(const Duration(minutes: 65)), '1 h 5 min');
    });

    test('the estimate uses a detour and a city speed', () async {
      final r = await const EstimateRouteService().route(0, 0, 0.1, 0);
      expect(r.estimated, isTrue);
      expect(r.distanceMeters, closeTo(11119 * 1.3, 50));
      expect(r.durationSeconds, closeTo(r.distanceMeters / (30000 / 3600), 1));
      expect(r.distanceText, endsWith('km'));
    });

    test('OSRM answer is parsed', () async {
      late Uri asked;
      final client = MockClient((req) async {
        asked = req.url;
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'distance': 12400.0,
                'duration': 1500.0,
                'geometry': {
                  'coordinates': [
                    [83.3013, 17.7231],
                    [83.31, 17.73],
                    [83.314, 17.733],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final r = await OsrmRouteService(client: client)
          .route(17.7231, 83.3013, 17.733, 83.314);
      expect(asked.path, contains('83.3013,17.7231;83.314,17.733'));
      expect(r.estimated, isFalse);
      expect(r.points.length, 3);
      expect(r.points.first, (17.7231, 83.3013));
      expect(r.distanceText, '12.4 km');
      expect(r.durationText, '25 min');
    });

    test('a failing server falls back to the estimate', () async {
      for (final client in [
        MockClient((_) async => http.Response('nope', 500)),
        MockClient((_) async => throw Exception('offline')),
        MockClient((_) async => http.Response('{"routes":[]}', 200)),
      ]) {
        final r = await OsrmRouteService(client: client)
            .route(17.7, 83.3, 17.8, 83.4);
        expect(r.estimated, isTrue);
        expect(r.durationSeconds, greaterThan(0));
      }
    });

    test('the cache asks once per route', () async {
      final svc = _CountingService();
      final cache = RouteCache(svc);
      await cache.planned(_bus());
      await cache.planned(_bus());
      expect(svc.calls, 1);
      await cache.planned(_bus(leg: Bus.returning));
      expect(svc.calls, 2);
      expect(cache.planned(_bus(end: null)), isNull);
      final moving = _bus().copyWith(lat: 17.725, lng: 83.305);
      await cache.remaining(moving);
      await cache.remaining(moving);
      expect(svc.calls, 3);
      expect(cache.remaining(_bus()), isNull); // no position yet
    });
  });

  group('automatic return route', () {
    late DemoBackend backend;
    late FakeLocation gps;
    late TripController trips;
    const driver = AppUser(
      uid: 'u-driver',
      email: 'driver@ecampus.demo',
      name: 'Dinesh Driver',
      department: 'MCA',
      role: UserRole.busDriver,
    );

    Future<Bus> bus() async => (await backend.watchBuses(driver).first)
        .firstWhere((b) => b.id == 'bus1');
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    setUp(() async {
      backend = DemoBackend();
      await backend.signIn('driver@ecampus.demo', DemoBackend.demoPassword);
      gps = FakeLocation();
      trips = TripController(backend, gps);
      await trips.start('bus1', bus: await bus());
    });
    tearDown(() {
      trips.dispose();
      backend.dispose();
    });

    test('a trip starts on the outbound leg', () async {
      expect((await bus()).leg, Bus.outbound);
      expect(trips.leg, Bus.outbound);
    });

    test(
      'reaching the end turns the bus back to the start, and again',
      () async {
        // Somewhere along the way: nothing changes.
        gps.controller.add(const GeoFix(17.728, 83.307));
        await settle();
        expect((await bus()).leg, Bus.outbound);
        // Arrives at the end point.
        gps.controller.add(const GeoFix(17.7330, 83.3140));
        await settle();
        expect((await bus()).leg, Bus.returning);
        expect(trips.leg, Bus.returning);
        // Still at the end point: no flip-flopping.
        gps.controller.add(const GeoFix(17.7330, 83.3140));
        await settle();
        expect((await bus()).leg, Bus.returning);
        // Arrives back at the start: outbound again.
        gps.controller.add(const GeoFix(17.7231, 83.3013));
        await settle();
        expect((await bus()).leg, Bus.outbound);
      },
    );

    test('arriving at the wrong end does nothing', () async {
      // Outbound, but the phone is at the start point.
      gps.controller.add(const GeoFix(17.7231, 83.3013));
      await settle();
      expect((await bus()).leg, Bus.outbound);
    });

    test('a new trip always starts outbound', () async {
      gps.controller.add(const GeoFix(17.7330, 83.3140));
      await settle();
      expect((await bus()).leg, Bus.returning);
      await trips.end('bus1');
      await trips.start('bus1', bus: await bus());
      expect((await bus()).leg, Bus.outbound);
    });

    test('a bus without a route just keeps sharing its position', () async {
      await trips.end('bus1');
      await backend.signIn('admin@ecampus.demo', DemoBackend.demoPassword);
      final plain = (await bus()).copyWith(clearRoute: true);
      await backend.saveBus(plain);
      await backend.signIn('driver@ecampus.demo', DemoBackend.demoPassword);
      await trips.start('bus1', bus: await bus());
      gps.controller.add(const GeoFix(17.7330, 83.3140));
      await settle();
      expect((await bus()).leg, Bus.outbound);
      expect((await bus()).lat, 17.7330);
    });
  });

  group('screens', () {
    testWidgets('admin sets a route on a bus and sees it listed', (t) async {
      final backend = await startApp(t);
      await login(t, 'admin@ecampus.demo');
      await openMenuItem(t, 'Manage Buses');
      expect(find.textContaining('Route: Gajuwaka Gate'), findsOneWidget);
      await t.tap(find.text('Add bus'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).at(0), 'Bus 7');
      await t.enterText(find.byType(TextFormField).at(1), 'MH 01');
      await t.tap(find.widgetWithText(FilterChip, 'Civil'));
      // Only one end set: refused.
      await t.enterText(find.byType(TextFormField).at(2), 'Depot');
      await t.enterText(find.byType(TextFormField).at(3), '18.5');
      await t.enterText(find.byType(TextFormField).at(4), '73.8');
      await t.ensureVisible(find.text('Save'));
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Set both the start and the end'),
        findsOneWidget,
      );
      await t.enterText(find.byType(TextFormField).at(5), 'Campus');
      await t.enterText(find.byType(TextFormField).at(6), '95'); // bad latitude
      await t.enterText(find.byType(TextFormField).at(7), '73.9');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Invalid'), findsOneWidget);
      await t.enterText(find.byType(TextFormField).at(6), '18.6');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.textContaining('Route: Depot'), findsOneWidget);
      final bus =
          (await backend
                  .watchBuses(
                    const AppUser(
                      uid: 'a',
                      email: 'a',
                      name: 'a',
                      department: 'MCA',
                      role: UserRole.admin,
                    ),
                  )
                  .first)
              .firstWhere((b) => b.name == 'Bus 7');
      expect(bus.start!.name, 'Depot');
      expect(bus.end!.lat, 18.6);
    });

    testWidgets('only one point set is refused; empty route is fine', (
      t,
    ) async {
      await startApp(t);
      await login(t, 'admin@ecampus.demo');
      await openMenuItem(t, 'Manage Buses');
      await t.tap(find.text('Add bus'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).at(0), 'Bus 8');
      await t.enterText(find.byType(TextFormField).at(1), 'MH 02');
      await t.tap(find.widgetWithText(FilterChip, 'Civil'));
      await t.enterText(find.byType(TextFormField).at(2), 'A');
      await t.enterText(find.byType(TextFormField).at(3), '1');
      await t.enterText(find.byType(TextFormField).at(4), '2');
      await t.ensureVisible(find.text('Save'));
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Set both the start and the end'),
        findsOneWidget,
      );
    });

    testWidgets('students see the route, trip time and live arrival time', (
      t,
    ) async {
      final backend = await startApp(t);
      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Bus Tracking');
      expect(
        find.text('Outbound: Gajuwaka Gate to College Campus'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('route-total')), findsOneWidget);
      expect(find.textContaining('(estimate)'), findsOneWidget);
      expect(find.byKey(const ValueKey('route-eta')), findsNothing);
      expect(find.byKey(const ValueKey('stop-from-bus1')), findsOneWidget);
      expect(find.byKey(const ValueKey('line-route-bus1')), findsOneWidget);
      // The bus is on its way.
      await backend.startTrip('bus1', 17.725, 83.305);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-eta')), findsOneWidget);
      expect(
        find.textContaining('Reaches College Campus in about'),
        findsOneWidget,
      );
      // After arrival the return route shows.
      await backend.setBusLeg('bus1', Bus.returning);
      await t.pumpAndSettle();
      expect(
        find.text('Return: College Campus to Gajuwaka Gate'),
        findsOneWidget,
      );
    });

    testWidgets('the driver sees where the bus is heading', (t) async {
      await startApp(t);
      await login(t, 'driver@ecampus.demo');
      await openMenuItem(t, 'Bus Tracking');
      expect(find.byKey(const ValueKey('heading-to')), findsNothing);
      await t.tap(find.text('Start trip'));
      await t.pumpAndSettle();
      expect(find.text('Now heading to College Campus'), findsOneWidget);
      expect(find.byKey(const ValueKey('route-eta')), findsOneWidget);
    });

    testWidgets('a bus with no route shows no route card', (t) async {
      await startApp(t);
      await login(t, 'meena@ecampus.demo'); // MBA: sees Bus 1 only
      await openMenuItem(t, 'Bus Tracking');
      expect(find.byKey(const ValueKey('route-info-bus1')), findsOneWidget);
      await signOutHelper(t);
      await login(t, 'admin@ecampus.demo');
      await openMenuItem(t, 'Bus Tracking');
      // Two buses: no single route is picked until one is selected.
      expect(find.byKey(const ValueKey('route-info-bus1')), findsNothing);
    });
  });
}

Future<void> signOutHelper(WidgetTester t) async {
  await openDrawer(t);
  await t.tap(find.text('Sign out'));
  await t.pumpAndSettle();
}
