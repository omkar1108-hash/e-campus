import 'dart:async';

/// Combines two live lists into one, de-duplicated by [id], newest values
/// of each. Emits once both have produced a first value, then on every
/// change of either. Errors from either stream are passed on. Completes when
/// both streams have completed.
Stream<List<T>> mergeLists<T>(
  Stream<List<T>> a,
  Stream<List<T>> b,
  String Function(T item) id,
) {
  late StreamController<List<T>> controller;
  StreamSubscription<List<T>>? subA;
  StreamSubscription<List<T>>? subB;
  List<T>? lastA;
  List<T>? lastB;
  var doneA = false;
  var doneB = false;

  void closeWhenDone() {
    if (doneA && doneB) controller.close();
  }

  void emit() {
    if (lastA == null || lastB == null) return;
    final byId = <String, T>{};
    for (final item in [...lastA!, ...lastB!]) {
      byId[id(item)] = item;
    }
    controller.add(byId.values.toList());
  }

  controller = StreamController<List<T>>(
    onListen: () {
      subA = a.listen(
        (v) {
          lastA = v;
          emit();
        },
        onError: controller.addError,
        onDone: () {
          doneA = true;
          closeWhenDone();
        },
      );
      subB = b.listen(
        (v) {
          lastB = v;
          emit();
        },
        onError: controller.addError,
        onDone: () {
          doneB = true;
          closeWhenDone();
        },
      );
    },
    onPause: () {
      subA?.pause();
      subB?.pause();
    },
    onResume: () {
      subA?.resume();
      subB?.resume();
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}
