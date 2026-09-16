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
      // زوج منافذ خاص بهالملف — ملفات الاختبار بتمشي بالتوازي، ومنافذ
      // ثابتة مشتركة بتخلّي مقبس ملف تاني ياكل حزمنا.
      const announce = 47316;
      const probe = 47317;
      final beacon = RoomBeacon(
        target: InternetAddress.loopbackIPv4,
        announcePort: announce,
        probePort: probe,
      );
      final discovery = RoomDiscovery(
        bindAddress: InternetAddress.loopbackIPv4,
        // هالاختبار لمسار البثّ — فالسؤال كمان على loopback، مش بثّ عام
        // (مقبس مربوط على loopback ما بيقدر يبعت بثّ عام أصلاً).
        probeTarget: InternetAddress.loopbackIPv4,
        listenPort: announce,
        probePort: probe,
      );

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
