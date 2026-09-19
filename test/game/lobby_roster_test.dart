/// اللوبي قبل ما تبلّش اللعبة: اللاعب اللي بيطلع بيروح من اللستة.
///
/// شكوى من اللعب الحقيقي: «لما يغيّر اللاعب اسمه بيطلع اسمين لنفس الشخص».
/// تغيير الاسم = طلوع ورجوع باسم جديد، والمضيف كان يخلّي القديم «منقطع»
/// باللستة — منطق صح **أثناء** اللعبة (حتى يرجع لنفس رقمه ونقاطه)، بس
/// باللوبي ما في رقم ولا نقاط نحافظ عليهن، فالشبح بس بيلخبط.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/engine.dart';
import 'package:meen_al_atlasy/game/events.dart';
import 'package:meen_al_atlasy/game/models.dart';

import 'fixtures.dart';

void main() {
  test('leaving the lobby removes the player, and seats close the gap', () {
    final engine = GameEngine(freshState(players: const []));
    engine.apply(const PlayerJoined('a1', 'سامر', TeamId.team1));
    engine.apply(const PlayerJoined('a2', 'هناء', TeamId.team1));
    engine.apply(const PlayerJoined('a3', 'زيد', TeamId.team1));
    expect(engine.state.matchStarted, isFalse);

    // هناء طلعت لتغيّر اسمها.
    engine.apply(const PlayerLeft('a2'));

    expect(engine.state.players.map((p) => p.id), ['a1', 'a3']);
    expect(engine.state.playersOf(TeamId.team1).map((p) => p.seat), [1, 2]);

    // رجعت باسم جديد — اسم واحد بس، ورقمها التالي.
    engine.apply(const PlayerJoined('a4', 'هناء ✨', TeamId.team1));
    expect(engine.state.players.map((p) => p.name), ['سامر', 'زيد', 'هناء ✨']);
    expect(engine.state.playersOf(TeamId.team1).map((p) => p.seat), [1, 2, 3]);
  });

  test('once the match has started a dropped player stays, disconnected, '
      'with their seat', () {
    final engine = GameEngine(freshState());
    engine.apply(const StartGame());

    engine.apply(const PlayerLeft('a2'));

    final a2 = engine.state.player('a2');
    expect(a2, isNotNull);
    expect(a2!.connected, isFalse);
    expect(a2.seat, 2);
    expect(engine.state.players, hasLength(6));
  });

  test('the last player of a team leaving the lobby marks the team empty', () {
    final engine = GameEngine(freshState(players: const []));
    engine.apply(const PlayerJoined('a1', 'سامر', TeamId.team1));
    engine.apply(const PlayerJoined('b1', 'ليلى', TeamId.team2));
    expect(engine.state.teams[TeamId.team2]!.connected, isTrue);

    engine.apply(const PlayerLeft('b1'));

    expect(engine.state.playersOf(TeamId.team2), isEmpty);
    expect(engine.state.teams[TeamId.team2]!.connected, isFalse);
  });
}
