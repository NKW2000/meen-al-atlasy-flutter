import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/network/host_server.dart';
import 'package:meen_al_atlasy/network/messages.dart';
import 'package:meen_al_atlasy/network/player_client.dart';

import '../game/fixtures.dart';

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
  group('HostServer <-> PlayerClient (loopback)', () {
    late HostServer server;
    late PlayerClient client;

    setUp(() {
      server = HostServer();
      client = PlayerClient();
    });

    tearDown(() async {
      await client.disconnect();
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
  });
}
