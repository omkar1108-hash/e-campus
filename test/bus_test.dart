import 'package:e_campus/models/app_user.dart';
import 'package:e_campus/models/bus.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:e_campus/services/location_source.dart';
import 'package:e_campus/services/trip_controller.dart';
import 'package:e_campus/utils/bus_status.dart';
import 'package:e_campus/utils/rbac.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

AppUser _u(String uid, UserRole role, {String dept = 'MCA'}) => AppUser(
  uid: uid,
  email: '$uid@x.y',
  name: uid,
  department: dept,
  role: role,
);

void main() {
  late DemoBackend backend;
  setUp(() => backend = DemoBackend());
  tearDown(() => backend.dispose());

  group('who sees which buses', () {
    test('students see only buses assigned to their department', () async {
      final mca = await backend
          .watchBuses(_u('s', UserRole.student, dept: 'MCA'))
          .first;
      expect(mca.map((b) => b.id), ['bus1']);
      final civil = await backend
          .watchBuses(_u('s', UserRole.classRep, dept: 'Civil'))
          .first;
      expect(civil.map((b) => b.id), ['bus2']);
      final none = await backend
          .watchBuses(_u('s', UserRole.student, dept: 'Electronics'))
          .first;
      expect(none, isEmpty);
    });

    test('admin, admin staff, teachers and library staff see all', () async {
      for (final r in [
        UserRole.admin,
        UserRole.adminStaff,
        UserRole.teacher,
        UserRole.libraryStaff,
      ]) {
        final buses = await backend.watchBuses(_u('x', r)).first;
        expect(buses.length, 2, reason: r.name);
      }
    });

    test('a driver sees only their own bus', () async {
      final mine = await backend
          .watchBuses(_u('u-driver', UserRole.busDriver))
          .first;
      expect(mine.map((b) => b.id), ['bus1']);
      final other = await backend
          .watchBuses(_u('someone-else', UserRole.busDriver))
          .first;
      expect(other, isEmpty);
    });
  });

  group('managing buses', () {
    test('create, edit and delete', () async {
      await backend.saveBus(
        const Bus(id: '', name: 'Bus 3', plate: 'XX 1', departments: ['MBA']),
      );
      var all = await backend.watchBuses(_u('a', UserRole.admin)).first;
      final created = all.firstWhere((b) => b.name == 'Bus 3');
      await backend.saveBus(created.copyWith(plate: 'XX 2', driverUid: 'd'));
      all = await backend.watchBuses(_u('a', UserRole.admin)).first;
      expect(all.firstWhere((b) => b.id == created.id).plate, 'XX 2');
      expect(all.firstWhere((b) => b.id == created.id).driverUid, 'd');
      await backend.deleteBus(created.id);
      all = await backend.watchBuses(_u('a', UserRole.admin)).first;
      expect(all.any((b) => b.id == created.id), isFalse);
    });

    test('editing configuration keeps a running trip', () async {
      await backend.startTrip('bus1', 1, 2);
      final bus = (await backend.watchBuses(_u('a', UserRole.admin)).first)
          .firstWhere((b) => b.id == 'bus1');
      await backend.saveBus(bus.copyWith(name: 'Renamed'));
      final after = (await backend.watchBuses(_u('a', UserRole.admin)).first)
          .firstWhere((b) => b.id == 'bus1');
      expect(after.name, 'Renamed');
      expect(after.active, isTrue);
      expect(after.lat, 1);
    });

    test('rbac: only admin and admin staff manage buses', () {
      for (final r in UserRole.values) {
        expect(
          Rbac.canManageBuses(_u('x', r)),
          r == UserRole.admin || r == UserRole.adminStaff,
          reason: r.name,
        );
      }
    });
  });

  group('trip lifecycle', () {
    test('start, move and end a trip', () async {
      final student = _u('s', UserRole.student);
      Future<Bus> bus() async =>
          (await backend.watchBuses(student).first).single;

      expect((await bus()).active, isFalse);
      await backend.startTrip('bus1', 17.1, 83.1);
      var b = await bus();
      expect(b.active, isTrue);
      expect(b.lat, 17.1);
      expect(b.tripStartedAt, isNotNull);
      await backend.updateTripLocation('bus1', 17.2, 83.2);
      b = await bus();
      expect(b.lat, 17.2);
      expect(b.isLive(DateTime.now()), isTrue);
      await backend.endTrip('bus1');
      b = await bus();
      expect(b.active, isFalse);
      expect(b.isLive(DateTime.now()), isFalse);
      // The last position is kept for "last known".
      expect(b.lat, 17.2);
    });

    test('a trip with no recent updates counts as signal lost', () {
      final old = DateTime.now().subtract(const Duration(minutes: 5));
      final b = Bus(
        id: 'b',
        name: 'B',
        plate: 'P',
        active: true,
        lat: 1,
        lng: 2,
        updatedAt: old,
      );
      expect(b.isLive(DateTime.now()), isFalse);
      expect(busStatus(b, DateTime.now()), startsWith('Signal lost'));
    });

    test('status text', () {
      final now = DateTime.now();
      expect(
        busStatus(const Bus(id: 'b', name: 'B', plate: 'P'), now),
        'Not running',
      );
      expect(
        busStatus(
          Bus(
            id: 'b',
            name: 'B',
            plate: 'P',
            active: true,
            lat: 1,
            lng: 2,
            updatedAt: now,
          ),
          now,
        ),
        startsWith('Live'),
      );
    });
  });

  group('TripController', () {
    test('publishes positions until the trip ends', () async {
      final gps = FakeLocation();
      final trips = TripController(backend, gps);
      final student = _u('s', UserRole.student);

      await trips.start('bus1');
      expect(trips.isTracking('bus1'), isTrue);
      expect((await backend.watchBuses(student).first).single.lat, 10);

      gps.controller.add(const GeoFix(11, 21));
      await Future<void>.delayed(Duration.zero);
      expect((await backend.watchBuses(student).first).single.lat, 11);

      await trips.end('bus1');
      expect(trips.isTracking('bus1'), isFalse);
      gps.controller.add(const GeoFix(99, 99));
      await Future<void>.delayed(Duration.zero);
      final b = (await backend.watchBuses(student).first).single;
      expect(b.active, isFalse);
      expect(b.lat, 11, reason: 'no updates after the trip ended');
      trips.dispose();
    });

    test('a GPS problem is reported and no trip starts', () async {
      final gps = FakeLocation()
        ..failWith = const LocationException(
          'Turn on location services first.',
        );
      final trips = TripController(backend, gps);
      await trips.start('bus1');
      expect(trips.error, contains('location services'));
      expect(trips.isTracking('bus1'), isFalse);
      final b =
          (await backend.watchBuses(_u('s', UserRole.student)).first).single;
      expect(b.active, isFalse);
      trips.dispose();
    });

    test('stopIfRunning ends the trip (used on sign out)', () async {
      final trips = TripController(backend, FakeLocation());
      await trips.start('bus1');
      await trips.stopIfRunning();
      final b =
          (await backend.watchBuses(_u('s', UserRole.student)).first).single;
      expect(b.active, isFalse);
      trips.dispose();
    });
  });
}
