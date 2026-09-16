/// غرفة كبيرة: ١٨ لاعب بغرفة وحدة. اللعبة ما فيها حد أعلى لعدد اللاعبين،
/// وهالاختبارات بتثبتها: الفرق بتتوزّع لحالها ٩/٩، الأرقام ١..٩ بكل فريق،
/// وكل رقم بيوصل عالمنصة لما تكون الجولات ١٦ — فما بيضل لاعب بلا دور.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/app/host_controller.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/game/settings.dart';
import 'package:meen_al_atlasy/network/host_server.dart';

import 'host_controller_fakes.dart';

/// ١٨ جهاز — كل واحد ببعت Join بدون فريق مطلوب، فالمضيف بيوزّعهم.
List<String> _eighteen() => [for (var i = 1; i <= 18; i++) 'ep$i'];

void main() {
  late FakeHostTransport transport;
  late FakeRoomBeacon beacon;

  HostController controller() => HostController(
        server: transport,
        beacon: beacon,
        newGame: bigGameState,
      );

  setUp(() {
    transport = FakeHostTransport();
    beacon = FakeRoomBeacon();
  });

  test('eighteen players all fit in one room, split evenly', () async {
    final vm = controller();
    await vm.startHosting();
    join(transport, _eighteen());
    await pump();

    expect(vm.state.players, hasLength(18));
    expect(vm.state.playersOf(TeamId.team1), hasLength(9));
    expect(vm.state.playersOf(TeamId.team2), hasLength(9));
    // ما في لاعب انسكّر اتصاله — يعني ما في حد أعلى بيرفض الزيادة.
    expect(transport.closed, isEmpty);
    expect(vm.canStart, isTrue);
  });

  test('every player gets their own seat, 1..9 in each team', () async {
    final vm = controller();
    await vm.startHosting();
    join(transport, _eighteen());
    await pump();

    for (final team in TeamId.values) {
      final seats = vm.state.playersOf(team).map((p) => p.seat).toList()..sort();
      expect(seats, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    }
    expect(vm.state.maxSeat, 9);
  });

  test('sixteen rounds bring every one of the nine seats to the podium', () {
    var state = bigGameState();
    for (var i = 1; i <= 18; i++) {
      final team = i.isOdd ? TeamId.team1 : TeamId.team2;
      final seat = (i / 2).ceil();
      state = state.copyWith(players: [
        ...state.players,
        Player(id: 'p$i', name: 'لاعب $i', teamId: team, seat: seat),
      ]);
    }

    // نفس دورة `GameEngine`: كل جولة بتنقّل الرقم للي بعده.
    final onStage = <int>{};
    for (var round = 0; round < GameSettings.maxRounds; round++) {
      onStage.add(state.podiumPlayer(TeamId.team1)!.seat);
      onStage.add(state.podiumPlayer(TeamId.team2)!.seat);
      // نفس `_Engine.nextSeat()` بالمحرك (extension خاص، مش مرئي هون).
      state = state.copyWith(faceOffSeat: (state.faceOffSeat % state.maxSeat) + 1);
    }

    expect(onStage, {1, 2, 3, 4, 5, 6, 7, 8, 9});
  });

  test('a player who leaves frees nobody else — the other 17 stay', () async {
    final vm = controller();
    await vm.startHosting();
    join(transport, _eighteen());
    await pump();

    transport.emit(ClientDisconnected('ep7'));
    await pump();

    expect(vm.state.players, hasLength(18));
    expect(vm.state.player('ep7')!.connected, isFalse);
    expect(vm.state.players.where((p) => p.connected), hasLength(17));
    expect(vm.canStart, isTrue);
  });
}
