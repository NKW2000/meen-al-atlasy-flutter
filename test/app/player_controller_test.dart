/// اختبارات [PlayerController] — نسخة عن `PlayerViewModelTest.kt` بالمشروع
/// الأصلي، بفارق بنية الاتصال: هون منستعمل `FakePlayerTransport` (تجريد
/// [PlayerTransport]، حكم المتحكمات ٦) بدل نسخة وهمية عن Nearby، ومنحاكي
/// اختيار الغرفة عبر `enterRoom` بدل `enterRoom(endpointId)`.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/app/player_controller.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/network/messages.dart';
import 'package:meen_al_atlasy/network/player_client.dart';
import 'package:meen_al_atlasy/network/room_discovery.dart';

class FakePlayerTransport implements PlayerTransport {
  @override
  final ValueNotifier<GameState?> state = ValueNotifier<GameState?>(null);
  @override
  final ValueNotifier<ConnectionStatus> status =
      ValueNotifier<ConnectionStatus>(ConnectionStatus.idle);
  @override
  final ValueNotifier<String?> playerId = ValueNotifier<String?>(null);
  @override
  final ValueNotifier<TeamId?> teamId = ValueNotifier<TeamId?>(null);

  final List<ClientMessage> sent = [];
  final List<(InternetAddress, int, String, TeamId?, String?)> connectCalls = [];
  int rejoinCalls = 0;
  int disconnectCalls = 0;
  int disposeCalls = 0;
  bool throwOnConnect = false;
  bool throwOnRejoin = false;

  @override
  Future<void> connect({
    required InternetAddress host,
    required int port,
    required String playerName,
    TeamId? teamId,
    String? playerId,
  }) async {
    connectCalls.add((host, port, playerName, teamId, playerId));
    if (throwOnConnect) throw Exception('تعذّر الاتصال');
    status.value = ConnectionStatus.connected;
  }

  @override
  void send(ClientMessage m) => sent.add(m);

  @override
  Future<void> rejoin() async {
    rejoinCalls++;
    if (throwOnRejoin) throw Exception('تعذّر الاتصال');
    status.value = ConnectionStatus.connected;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    status.value = ConnectionStatus.disconnected;
  }

  @override
  Future<void> leave() async {
    await disconnect();
    status.value = ConnectionStatus.idle;
    state.value = null;
    playerId.value = null;
    teamId.value = null;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

/// بديل بالذاكرة عن [RoomDiscovery] — بيسجّل نداءات start/stop بدون بثّ
/// UDP حقيقي؛ الغرف بتنحط يدوياً بالاختبار عبر `rooms.value`.
class FakeRoomDiscovery extends RoomDiscovery {
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> start() async {
    startCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

GameState _state({
  RoundPhase phase = RoundPhase.faceOff,
  TeamId? controllingTeam,
  String? turnPlayerId,
  Set<String> wrongPlayers = const {},
}) =>
    GameState(
      questions: [
        Question(
          id: 'q1',
          text: '',
          category: 'عام',
          answers: const [Answer(text: '', points: 100)],
        ),
      ],
      phase: phase,
      controllingTeam: controllingTeam,
      turnPlayerId: turnPlayerId,
      wrongPlayers: wrongPlayers,
      players: const [
        Player(id: 'p-a', name: 'سامر', teamId: TeamId.team1, seat: 1),
        Player(id: 'p-b', name: 'ليلى', teamId: TeamId.team2, seat: 1),
      ],
      teams: const {
        TeamId.team1: TeamState(id: TeamId.team1, name: 'الفريق الأخضر'),
        TeamId.team2: TeamState(id: TeamId.team2, name: 'الفريق الأزرق'),
      },
    );

void main() {
  late FakePlayerTransport transport;
  late FakeRoomDiscovery discovery;
  late PlayerController controller;

  setUp(() {
    transport = FakePlayerTransport();
    discovery = FakeRoomDiscovery();
    controller = PlayerController(discovery: discovery, client: transport, clock: () => 777);
  });

  Future<void> connect({String playerId = 'p-b', TeamId team = TeamId.team2}) async {
    controller.join('ليلى');
    final room = Room('غرفة', InternetAddress.loopbackIPv4, 1234);
    await controller.enterRoom(room);
    transport.playerId.value = playerId;
    transport.teamId.value = team;
  }

  test('join starts discovery and holds the name until a room is entered',
      () async {
    controller.join('سامر');

    expect(controller.discovering, isTrue);
    expect(discovery.startCalls, equals(1));
    expect(transport.connectCalls, isEmpty);

    final room = Room('غرفة', InternetAddress.loopbackIPv4, 4000);
    await controller.enterRoom(room);

    expect(controller.discovering, isFalse);
    expect(discovery.stopCalls, equals(1));
    expect(transport.connectCalls, hasLength(1));
    expect(transport.connectCalls.single.$3, equals('سامر'));
    expect(controller.status, equals(ConnectionStatus.connected));
  });

  test('joining again while already connected resends the join with the '
      'remembered playerId', () async {
    await connect();
    controller.join('ليلى الجديدة');

    expect(transport.sent.last, isA<JoinMessage>());
    final msg = transport.sent.last as JoinMessage;
    expect(msg.playerName, equals('ليلى الجديدة'));
    expect(msg.playerId, equals('p-b'));
    // ما بيرجع يدوّر — هو متّصل أصلاً (نفس عدد النداءات من أول اتصال).
    expect(discovery.startCalls, equals(1));
  });

  test("the host decides this device's player id and team", () async {
    await connect();

    expect(controller.playerId, equals('p-b'));
    expect(controller.teamId, equals(TeamId.team2));
  });

  test('the buzzer only works when the host armed this player', () async {
    await connect();
    transport.state.value = _state(); // فيز-أوف: منصّة كل فريق مسلّحة

    expect(controller.canBuzz(), isTrue); // p-b هو لاعب المنصة لفريقه
    expect(controller.mark(), equals(PlayerMark.armed));

    controller.onBuzzTapped();
    expect(transport.sent.last, equals(BuzzMessage(playerId: 'p-b', atMillis: 777)));
  });

  test('a player who is not on turn cannot buzz', () async {
    await connect();
    transport.state.value = _state(
      phase: RoundPhase.play,
      controllingTeam: TeamId.team1,
      turnPlayerId: 'p-a',
    );

    expect(controller.canBuzz(), isFalse);
    expect(controller.mark(), equals(PlayerMark.idle));
    controller.onBuzzTapped();
    expect(transport.sent.whereType<BuzzMessage>(), isEmpty);
  });

  test('a wrong ruling turns this device red', () async {
    await connect();
    transport.state.value = _state(
      phase: RoundPhase.play,
      controllingTeam: TeamId.team2,
      turnPlayerId: 'p-a',
      wrongPlayers: {'p-b'},
    );

    expect(controller.mark(), equals(PlayerMark.wrong));
    expect(controller.canBuzz(), isFalse);
  });

  test('buzzing does nothing before the host assigns a player id', () async {
    controller.join('ليلى');
    await controller.enterRoom(Room('غرفة', InternetAddress.loopbackIPv4, 1));
    transport.state.value = _state();

    expect(controller.playerId, isNull);
    controller.onBuzzTapped();
    expect(transport.sent.whereType<BuzzMessage>(), isEmpty);
  });

  test('losing the host flips the status to disconnected', () async {
    await connect();
    await transport.disconnect();

    expect(controller.status, equals(ConnectionStatus.disconnected));
    expect(controller.canBuzz(), isFalse);
  });

  test('a failed connection reports the error and resumes searching so the room '
      'list comes back without leaving the screen', () async {
    transport.throwOnConnect = true;
    controller.join('سامر');
    expect(discovery.startCalls, equals(1));

    await controller.enterRoom(Room('غرفة', InternetAddress.loopbackIPv4, 4000));

    expect(controller.lastError, equals('تعذّر الاتصال بالمضيف'));
    expect(controller.status, isNot(ConnectionStatus.connected));
    // البحث رجع لحاله — مش لازم يطلع ويرجع يفوت حتى يشوف الغرف.
    expect(controller.discovering, isTrue);
    expect(discovery.startCalls, equals(2));
  });

  test('leave disconnects and forgets the room, the seat and the game state — '
      'but keeps the name for the next join', () async {
    await connect();
    transport.state.value = _state();
    expect(controller.state, isNotNull);

    await controller.leave();

    expect(transport.disconnectCalls, equals(1));
    expect(controller.status, equals(ConnectionStatus.idle));
    expect(controller.state, isNull);
    expect(controller.playerId, isNull);
    expect(controller.teamId, isNull);
    expect(controller.rooms, isEmpty);
    expect(controller.pendingName, equals('ليلى'));

    // الانضمام من جديد بيبلّش بحث جديد بدل ما يبعت الاسم على اتصال قديم.
    controller.join('ليلى');
    expect(discovery.startCalls, equals(2));
    expect(transport.sent.whereType<JoinMessage>(), isEmpty);
  });

  test('choose is only sent during play-or-pass and only for this player',
      () async {
    await connect();
    transport.state.value = _state(phase: RoundPhase.playOrPass);

    controller.choose(true);
    expect(transport.sent.last, equals(ChooseMessage(playerId: 'p-b', play: true)));

    transport.state.value = _state(phase: RoundPhase.play);
    transport.sent.clear();
    controller.choose(false);
    expect(transport.sent, isEmpty);
  });

  test('changeTeam sends the request and remembers the new pending team',
      () async {
    await connect();
    controller.changeTeam(TeamId.team1);
    expect(
      transport.sent.last,
      equals(ChangeTeamMessage(playerId: 'p-b', teamId: TeamId.team1)),
    );
  });

  test('rejoin reconnects through the transport and clears the error',
      () async {
    await connect();
    controller.join('ليلى'); // بس حتى نضمن pendingName محفوظ
    await controller.rejoin();

    expect(transport.rejoinCalls, equals(1));
    expect(controller.lastError, isNull);
  });

  test('an accidental drop reconnects on its own, without asking the player',
      () async {
    await connect();
    controller.join('ليلى');
    expect(transport.rejoinCalls, 0);

    // انقطع الواي فاي لثانية — المضيف بيضل ماسك مكان اللاعب ونقاطه.
    transport.status.value = ConnectionStatus.disconnected;
    expect(controller.reconnecting, isTrue, reason: 'لازم يحاول قبل ما يسأل');

    // أول محاولة بعد ثانية.
    await Future.delayed(const Duration(milliseconds: 1200));

    expect(transport.rejoinCalls, greaterThanOrEqualTo(1));
    expect(controller.status, ConnectionStatus.connected);
    expect(controller.reconnecting, isFalse);
  });

  test('it keeps trying a few times, then stops asking the player to wait',
      () async {
    await connect();
    controller.join('ليلى');
    transport.throwOnRejoin = true;

    transport.status.value = ConnectionStatus.disconnected;
    // ١+٢+٣+٤+٥ ثواني بين المحاولات — منستنى كفاية لكلهم.
    await Future.delayed(const Duration(seconds: 16));

    expect(transport.rejoinCalls, 5);
    // خلصت المحاولات — هلق الشاشة بتسأل اللاعب.
    expect(controller.reconnecting, isFalse);
    expect(controller.status, ConnectionStatus.disconnected);
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('leaving on purpose never triggers an automatic rejoin', () async {
    await connect();
    controller.join('ليلى');
    await controller.leave();

    await Future.delayed(const Duration(milliseconds: 1400));

    expect(transport.rejoinCalls, 0);
    expect(controller.reconnecting, isFalse);
  });

  test('a manual rejoin after the tries ran out starts the count over',
      () async {
    await connect();
    controller.join('ليلى');
    transport.throwOnRejoin = true;
    transport.status.value = ConnectionStatus.disconnected;
    await Future.delayed(const Duration(seconds: 16));
    expect(transport.rejoinCalls, 5);

    // اللاعب دوس «ارجع لللعبة» — منجرب من جديد.
    transport.throwOnRejoin = false;
    await controller.rejoin();

    expect(transport.rejoinCalls, 6);
    expect(controller.status, ConnectionStatus.connected);
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('rejoin does nothing before a name was ever set', () async {
    await controller.rejoin();
    expect(transport.rejoinCalls, equals(0));
  });

  test('enterCode reports the exact "no wifi" message when the device has '
      'no local IP', () async {
    final c = PlayerController(
      discovery: discovery,
      client: transport,
      localIp: () async => null,
    );
    c.join('سامر');

    await c.enterCode('12345');

    expect(c.lastError, equals('افتح الواي فاي أو نقطة الاتصال'));
    expect(transport.connectCalls, isEmpty);
  });

  test('enterCode reports the exact "bad code" message for a malformed code',
      () async {
    final c = PlayerController(
      discovery: discovery,
      client: transport,
      localIp: () async => InternetAddress('192.168.1.7'),
    );
    c.join('سامر');

    await c.enterCode('abc'); // مش ٥ أرقام

    expect(c.lastError, equals('كود الغرفة مش صحيح'));
    expect(transport.connectCalls, isEmpty);
  });

  test('enterCode connects using the address decoded from a valid code',
      () async {
    final c = PlayerController(
      discovery: discovery,
      client: transport,
      localIp: () async => InternetAddress('192.168.1.7'),
    );
    c.join('سامر');

    // decodeRoomCode('00001', 192.168.1.7) => 192.168.0.1 (الثالث=٠، الرابع=١)
    await c.enterCode('00001');

    expect(c.lastError, isNull);
    expect(transport.connectCalls, hasLength(1));
    expect(transport.connectCalls.single.$1, equals(InternetAddress('192.168.0.1')));
  });

  test('dismissError clears the last error', () async {
    final c = PlayerController(
      discovery: discovery,
      client: transport,
      localIp: () async => null,
    );
    c.join('سامر');
    await c.enterCode('12345');
    expect(c.lastError, isNotNull);

    c.dismissError();
    expect(c.lastError, isNull);
  });

  test('dispose detaches listeners and disconnects without throwing',
      () async {
    await connect();
    expect(() => controller.dispose(), returnsNormally);
  });
}
