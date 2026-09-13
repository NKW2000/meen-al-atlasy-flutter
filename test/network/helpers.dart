/// أدوات مساعدة مشتركة لاختبارات الشبكة.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// بينتظر لحد ما قيمة [notifier] تحقق [predicate]، أو تنتهي المهلة.
Future<void> waitForValue<T>(
  ValueListenable<T> notifier,
  bool Function(T value) predicate, {
  Duration timeout = const Duration(seconds: 10),
}) {
  if (predicate(notifier.value)) return Future.value();
  final completer = Completer<void>();
  late final VoidCallback listener;
  listener = () {
    if (predicate(notifier.value) && !completer.isCompleted) {
      notifier.removeListener(listener);
      completer.complete();
    }
  };
  notifier.addListener(listener);
  return completer.future.timeout(
    timeout,
    onTimeout: () {
      notifier.removeListener(listener);
      throw TimeoutException(
          'value never satisfied predicate (last: ${notifier.value})');
    },
  );
}
