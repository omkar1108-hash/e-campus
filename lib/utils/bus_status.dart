import '../models/bus.dart';

String _ago(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds.clamp(0, 59)}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  return '${d.inHours} h ago';
}

/// Human readable state of a bus for lists.
String busStatus(Bus b, DateTime now) {
  if (b.isLive(now)) {
    return 'Live · updated ${_ago(now.difference(b.updatedAt!))}';
  }
  if (b.active && b.updatedAt != null) {
    return 'Signal lost · last seen ${_ago(now.difference(b.updatedAt!))}';
  }
  if (b.active) {
    return 'Trip starting…';
  }
  return 'Not running';
}
