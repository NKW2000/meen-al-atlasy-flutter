@Tags(['network'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/network/room_beacon.dart';
import 'package:meen_al_atlasy/network/room_discovery.dart';

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

void main() {
  test(
    'RoomBeacon is found by RoomDiscovery on loopback, then expires',
    () async {
      final beacon = RoomBeacon(target: InternetAddress.loopbackIPv4);
      final discovery =
          RoomDiscovery(bindAddress: InternetAddress.loopbackIPv4);

      try {
        await discovery.start();
        await beacon.start(roomName: 'غرفة الاختبار', port: 12345);

        await waitForValue(
          discovery.rooms,
          (rooms) => rooms.any((r) => r.name == 'غرفة الاختبار' && r.port == 12345),
          timeout: const Duration(seconds: 3),
        );

        await beacon.stop();

        await waitForValue(
          discovery.rooms,
          (rooms) => rooms.every((r) => r.name != 'غرفة الاختبار'),
          timeout: const Duration(seconds: 6),
        );
      } finally {
        await beacon.stop();
        await discovery.stop();
      }
    },
    skip: Platform.environment['CI'] == 'true'
        ? 'UDP loopback broadcast may be blocked on CI runners'
        : false,
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
