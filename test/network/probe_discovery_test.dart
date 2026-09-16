/// المسار التاني للاكتشاف: اللاعب بيسأل والمضيف بيجاوب مباشرة (unicast).
///
/// هاد اللي بيحلّ «الغرفة ما بتبيّن عند بعض الأجهزة وهي على نفس الشبكة»:
/// البثّ (broadcast) بيوصل أو ما بيوصل حسب الراوتر وتوفير الطاقة، فمنارة
/// المضيف لحالها مش كفاية. بهالاختبار المنارة **ما بتبثّ أبداً**
/// ([_SilentBeacon] بتلغي `announce`) ولازم اللاعب يلاقي الغرفة رغم هيك.
@Tags(['network'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/network/room_beacon.dart';
import 'package:meen_al_atlasy/network/room_discovery.dart';

import 'helpers.dart';

/// منارة ما بتعلن أبداً — كل الاكتشاف لازم يجي من جواب السؤال.
/// زوج منافذ خاص بهالملف — شوف التعليق بـ`discovery_test.dart`.
const int _announcePort = 47416;
const int _probePort = 47417;

class _SilentBeacon extends RoomBeacon {
  _SilentBeacon()
      : super(
          target: InternetAddress.loopbackIPv4,
          announcePort: _announcePort,
          probePort: _probePort,
        );

  int announceCalls = 0;

  @override
  Future<void> announce() async => announceCalls++; // بلا بثّ
}

void main() {
  test(
    'a room with no broadcast at all is still found, by probe and unicast reply',
    () async {
      final beacon = _SilentBeacon();
      final discovery = RoomDiscovery(
        bindAddress: InternetAddress.loopbackIPv4,
        probeTarget: InternetAddress.loopbackIPv4,
        listenPort: _announcePort,
        probePort: _probePort,
      );

      try {
        await beacon.start(roomName: 'غرفة بلا بثّ', port: 12346);
        await discovery.start();

        await waitForValue(
          discovery.rooms,
          (rooms) => rooms.any((r) => r.name == 'غرفة بلا بثّ' && r.port == 12346),
          timeout: const Duration(seconds: 6),
        );

        // ما انبثّ ولا إعلان — الغرفة بانت من الجواب المباشر بس.
        expect(beacon.announceCalls, greaterThan(0));
      } finally {
        await beacon.stop();
        await discovery.stop();
      }
    },
    skip: Platform.environment['CI'] == 'true'
        ? 'UDP loopback may be blocked on CI runners'
        : false,
    timeout: const Timeout(Duration(seconds: 20)),
  );

  test('a probe packet is never mistaken for a room', () {
    final discovery = RoomDiscovery(bindAddress: InternetAddress.loopbackIPv4);

    // سؤال لاعب تاني وصل لمقبسنا — ما بيصير غرفة.
    discovery.handlePacket(
      InternetAddress.loopbackIPv4,
      '{"probe":1,"version":1}'.codeUnits,
    );

    expect(discovery.rooms.value, isEmpty);
  });

  test('the beacon stops answering probes once it is stopped', () async {
    final beacon = _SilentBeacon();
    await beacon.start(roomName: 'غرفة', port: 1);
    await beacon.stop();

    // إعادة التشغيل لازم تنجح — يعني المقبس القديم انسكّر فعلاً وما ضل
    // حاجز المنفذ (كان بيصير لو نسينا نسكّر مقبس الأسئلة).
    await beacon.start(roomName: 'غرفة تانية', port: 2);
    await beacon.stop();
  }, skip: Platform.environment['CI'] == 'true' ? 'binds a UDP port' : false);
}
