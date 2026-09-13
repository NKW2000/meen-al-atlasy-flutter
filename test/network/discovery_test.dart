@Tags(['network'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/network/room_beacon.dart';
import 'package:meen_al_atlasy/network/room_discovery.dart';

import 'helpers.dart';

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
          timeout: const Duration(seconds: 9),
        );
      } finally {
        await beacon.stop();
        await discovery.stop();
      }
    },
    skip: Platform.environment['CI'] == 'true'
        ? 'UDP loopback broadcast may be blocked on CI runners'
        : false,
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
