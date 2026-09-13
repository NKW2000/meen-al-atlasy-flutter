import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/network/host_server.dart';
import 'package:meen_al_atlasy/network/messages.dart';
import 'package:meen_al_atlasy/network/player_client.dart';

import '../game/fixtures.dart';
import 'helpers.dart';

void main() {
  group('HostServer <-> PlayerClient (loopback)', () {
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

    test('connect, join, assign, broadcast state, and disconnect', () async {
      await server.start(port: 0);
      expect(server.port, greaterThan(0));

      final received = <ClientEvent>[];
      final sub = server.events.listen(received.add);

      await client.connect(
        host: InternetAddress.loopbackIPv4,
        port: server.port,
        playerName: 'سلمان',
      );

      expect(client.status.value, equals(ConnectionStatus.connected));

      // انتظر وصول حدث الاتصال ثم رسالة الانضمام على المضيف.
      await Future.doWhile(() async {
        if (received.length >= 2) return false;
        await Future.delayed(const Duration(milliseconds: 20));
        return true;
      }).timeout(const Duration(seconds: 5));

      expect(received[0], isA<ClientConnected>());
      final endpointId = received[0].endpointId;

      expect(received[1], isA<ClientMessageReceived>());
      final joinMsg = (received[1] as ClientMessageReceived).message;
      expect(joinMsg, isA<JoinMessage>());
      expect((joinMsg as JoinMessage).playerName, equals('سلمان'));

      server.send(endpointId, Assigned(playerId: 'p1', teamId: TeamId.team1));

      await waitForValue(client.playerId, (v) => v == 'p1');
      expect(client.teamId.value, equals(TeamId.team1));

      final masked = freshState().maskedForPlayers();
      server.broadcast(StateUpdate(state: masked));

      await waitForValue(client.state, (v) => v == masked);

      await server.stop();

      await waitForValue(
        client.status,
        (v) => v == ConnectionStatus.disconnected,
      );

      await sub.cancel();
    }, timeout: const Timeout(Duration(seconds: 20)));

    test(
      'reconnecting to the same server closes the previous socket without '
      'flipping status away from connected',
      () async {
        await server.start(port: 0);

        await client.connect(
          host: InternetAddress.loopbackIPv4,
          port: server.port,
          playerName: 'أ',
        );
        expect(client.status.value, equals(ConnectionStatus.connected));

        // اتصال ثاني بنفس الخادم — لازم يسكّر الأول من تحت الطاولة، بدون
        // ما حدث إغلاقه (onDone) يقلب حالة الاتصال الثاني.
        await client.connect(
          host: InternetAddress.loopbackIPv4,
          port: server.port,
          playerName: 'أ',
        );
        expect(client.status.value, equals(ConnectionStatus.connected));

        // ننتظر شوي حتى ينوصل حدث إغلاق الـ socket الأول (لو رح يوصل) —
        // ما لازم يقلب حالة الاتصال الثاني لـ disconnected.
        await Future.delayed(const Duration(milliseconds: 300));
        expect(client.status.value, equals(ConnectionStatus.connected));
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test(
      'stop() while a client connect is racing in flight completes without '
      'throwing',
      () async {
        await server.start(port: 0);
        final port = server.port;

        // ما منستنى الاتصال يخلص — منوقف الخادم فوراً لمحاكاة السباق بين
        // stop() وترقية WebSocket لسا عم تصير.
        final connectFuture = WebSocket.connect('ws://127.0.0.1:$port/');

        await server.stop();

        // النتيجة (نجاح أو فشل) مش المهمة — المهم ما في استثناء غير ملتقط
        // وما تعلّق stop() (اللي خلصت فوق أصلاً).
        try {
          final ws = await connectFuture;
          await ws.close();
        } catch (_) {
          // اتصال العميل ممكن ينقطع بسبب السباق — متوقع وسليم.
        }
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });
}
