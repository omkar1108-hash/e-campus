import 'dart:async';

import 'dart:convert';

import 'package:e_campus/services/image_service.dart';
import 'package:e_campus/services/location_source.dart';
import 'package:image/image.dart' as img;

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

/// A small valid picture (base64 JPEG) for tests.
String tinyPicture() =>
    base64Encode(img.encodeJpg(img.Image(width: 64, height: 36)));

/// Gallery / camera stand-in: returns the queued picture, or null (cancel).
class FakeImagePicker implements ImagePickerService {
  FakeImagePicker([this.next]);

  String? next;
  Object? failWith;
  int picks = 0;

  @override
  bool get cameraAvailable => false;

  @override
  Future<String?> pick({bool camera = false}) async {
    picks++;
    if (failWith != null) throw failWith!;
    return next;
  }
}
