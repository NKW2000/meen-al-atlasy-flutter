/// اختبار مخصّص لـ [PlayerClient.rejoin] — يتأكد إنه رسالة الانضمام
/// المعادة بتحمل [JoinMessage.playerId] المحفوظ من آخر [HostMessage.Assigned]
/// (Task 6، حكم ١ج).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/network/host_server.dart';
import 'package:meen_al_atlasy/network/messages.dart';
import 'package:meen_al_atlasy/network/player_client.dart';

import '../game/fixtures.dart';
import 'helpers.dart';

void main() {
  group('PlayerClient.rejoin', () {
    late HostServer server;
    late PlayerClient client;

    setUp(() {
      server = HostServer();
      client = PlayerClient();
    });

    tearDown(() async {
      await client.dispose();
      await server.stop();
    });

    test('first join has no playerId, and rejoin resends the assigned id', () async {
      await server.start(port: 0);

      final received = <ClientEvent>[];
      final sub = server.events.listen(received.add);

      await client.connect(
        host: InternetAddress.loopbackIPv4,
        port: server.port,
        playerName: 'ريم',
      );

      await Future.doWhile(() async {
        if (received.length >= 2) return false;
        await Future.delayed(const Duration(milliseconds: 20));
        return true;
      }).timeout(const Duration(seconds: 5));

      final firstJoin =
          (received[1] as ClientMessageReceived).message as JoinMessage;
      expect(firstJoin.playerId, isNull);

      final firstEndpoint = received[0].endpointId;
      server.send(firstEndpoint, Assigned(playerId: 'p-42', teamId: TeamId.team1));
      await waitForValue(client.playerId, (v) => v == 'p-42');

      await client.rejoin();

      // منستنى رسالة الانضمام التانية نفسها — مش عدد الأحداث: إغلاق الـ
      // socket الأول بيولّد ClientDisconnected كمان، وترتيبه نسبةً للاتصال
      // الجديد بيختلف بين الأنظمة (على لينكس بيوصل قبل الانضمام التاني).
      await Future.doWhile(() async {
        if (received.whereType<ClientMessageReceived>().length >= 2) {
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 20));
        return true;
      }).timeout(const Duration(seconds: 5));

      final rejoinMessage =
          received.whereType<ClientMessageReceived>().last.message as JoinMessage;
      expect(rejoinMessage.playerName, equals('ريم'));
      expect(rejoinMessage.playerId, equals('p-42'));

      await sub.cancel();
    }, timeout: const Timeout(Duration(seconds: 20)));

    test(
      'a fresh connect() after a previous session sends no playerId, even '
      'though the field still remembers the old one (review critical #2)',
      () async {
        await server.start(port: 0);
        final received = <ClientEvent>[];
        final sub = server.events.listen(received.add);

        await client.connect(
          host: InternetAddress.loopbackIPv4,
          port: server.port,
          playerName: 'أ',
        );
        await Future.doWhile(() async {
          if (received.length >= 2) return false;
          await Future.delayed(const Duration(milliseconds: 20));
          return true;
        }).timeout(const Duration(seconds: 5));

        final firstEndpoint = received[0].endpointId;
        server.send(firstEndpoint, Assigned(playerId: 'ep0', teamId: TeamId.team1));
        await waitForValue(client.playerId, (v) => v == 'ep0');
        server.broadcast(StateUpdate(state: freshState().maskedForPlayers()));
        await waitForValue(client.state, (v) => v != null);

        // اتصال **جديد** — مو rejoin — مثلاً اللاعب دخل غرفة/لعبة تانية.
        // معرّف 'ep0' القديم لازم يترك، حتى لو لسا محفوظ بحقل الحالة.
        await client.connect(
          host: InternetAddress.loopbackIPv4,
          port: server.port,
          playerName: 'أ',
        );

        await Future.doWhile(() async {
          if (received.whereType<ClientMessageReceived>().length >= 2) {
            return false;
          }
          await Future.delayed(const Duration(milliseconds: 20));
          return true;
        }).timeout(const Duration(seconds: 5));

        final secondJoin = received
            .whereType<ClientMessageReceived>()
            .last
            .message as JoinMessage;
        expect(secondJoin.playerId, isNull);
        expect(client.playerId.value, isNull);
        // ولا حالة لعبة قديمة — اللوح بيضل فاضي لحد ما يبعت المضيف الجديد.
        expect(client.state.value, isNull);

        await sub.cancel();
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });
}
