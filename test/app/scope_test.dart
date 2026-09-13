/// اختبار [AppScope] — يتأكد إنه بيوصّل المتحكمات لشجرة الواجهة وبيعيد
/// بناء المعتمدين عليه بس لما تتغيّر.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/app/host_controller.dart';
import 'package:meen_al_atlasy/app/player_controller.dart';
import 'package:meen_al_atlasy/app/scope.dart';
import 'package:meen_al_atlasy/app/settings_repository.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/network/host_server.dart';
import 'package:meen_al_atlasy/network/messages.dart';
import 'package:meen_al_atlasy/network/player_client.dart';
import 'package:meen_al_atlasy/network/room_beacon.dart';
import 'package:meen_al_atlasy/network/room_discovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopTransport implements HostTransport {
  final _controller = StreamController<ClientEvent>.broadcast();
  @override
  int get port => 0;
  @override
  Stream<ClientEvent> get events => _controller.stream;
  @override
  Future<void> start({int port = defaultHostPort}) async {}
  @override
  void send(String endpointId, HostMessage m) {}
  @override
  void broadcast(HostMessage m) {}
  @override
  Future<void> stop() async {}
}

class _NoopBeacon extends RoomBeacon {
  @override
  Future<void> start({required String roomName, required int port}) async {}
  @override
  Future<void> stop() async {}
}

class _NoopPlayerTransport implements PlayerTransport {
  @override
  final ValueNotifier<GameState?> state = ValueNotifier(null);
  @override
  final ValueNotifier<ConnectionStatus> status =
      ValueNotifier(ConnectionStatus.idle);
  @override
  final ValueNotifier<String?> playerId = ValueNotifier(null);
  @override
  final ValueNotifier<TeamId?> teamId = ValueNotifier(null);
  @override
  Future<void> connect({
    required InternetAddress host,
    required int port,
    required String playerName,
    TeamId? teamId,
    String? playerId,
  }) async {}
  @override
  void send(ClientMessage m) {}
  @override
  Future<void> rejoin() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppScope.of exposes the host, player and settings it was given',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('scope_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final host = HostController(
      server: _NoopTransport(),
      beacon: _NoopBeacon(),
      newGame: () => GameState(questions: const [], teams: const {
        TeamId.team1: TeamState(id: TeamId.team1, name: 'أ'),
        TeamId.team2: TeamState(id: TeamId.team2, name: 'ب'),
      }),
    );
    final player = PlayerController(
      discovery: RoomDiscovery(),
      client: _NoopPlayerTransport(),
    );
    final settings = SettingsRepository(await SharedPreferences.getInstance(), tempDir);

    late BuildContext captured;
    await tester.pumpWidget(
      AppScope(
        host: host,
        player: player,
        settings: settings,
        child: Builder(builder: (context) {
          captured = context;
          return const SizedBox();
        }),
      ),
    );

    final scope = AppScope.of(captured);
    expect(scope.host, same(host));
    expect(scope.player, same(player));
    expect(scope.settings, same(settings));
  });

  testWidgets('updateShouldNotify is true only when a controller reference changes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('scope_test2');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    GameState newGame() => GameState(questions: const [], teams: const {
          TeamId.team1: TeamState(id: TeamId.team1, name: 'أ'),
          TeamId.team2: TeamState(id: TeamId.team2, name: 'ب'),
        });

    final host = HostController(server: _NoopTransport(), beacon: _NoopBeacon(), newGame: newGame);
    final player = PlayerController(discovery: RoomDiscovery(), client: _NoopPlayerTransport());
    final settings = SettingsRepository(await SharedPreferences.getInstance(), tempDir);

    final widget = AppScope(host: host, player: player, settings: settings, child: const SizedBox());
    final sameAgain = AppScope(host: host, player: player, settings: settings, child: const SizedBox());
    final different = AppScope(
      host: HostController(server: _NoopTransport(), beacon: _NoopBeacon(), newGame: newGame),
      player: player,
      settings: settings,
      child: const SizedBox(),
    );

    expect(widget.updateShouldNotify(sameAgain), isFalse);
    expect(widget.updateShouldNotify(different), isTrue);
  });
}
