import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/engine.dart';
import 'package:meen_al_atlasy/game/events.dart';
import 'package:meen_al_atlasy/game/models.dart';

import 'fixtures.dart';

/// دور اللاعبين: مين بيقدر يضغط، ترتيب الدور، وألوان الشاشات.
void main() {
  test('only the podium player of each team may buzz in the face-off', () {
    final engine = GameEngine(freshState());
    expect(engine.state.armedPlayerIds(), {'a1', 'b1'});

    final ignored = engine.buzz('a2');
    expect(ignored.buzzState, BuzzState.open);
    expect(ignored.buzzedPlayerId, isNull);

    final locked = engine.buzz('a1');
    expect(locked.buzzState, BuzzState.lockedTeam1);
    expect(locked.buzzedPlayerId, 'a1');
    expect(locked.markFor('a1'), PlayerMark.buzzed);
  });

  test('control passes to the next team mate, not the one who just answered', () {
    final engine = GameEngine(freshState());
    final playing = engine.giveControlTo(TeamId.team1);

    // a1 جاوب بالمواجهة، فالدور بينتقل لـ a2.
    expect(playing.turnPlayerId, 'a2');
    expect(playing.armedPlayerIds(), {'a2'});
    expect(playing.markFor('a2'), PlayerMark.armed);
    expect(playing.markFor('a1'), PlayerMark.correct);
  });

  test('the team answers in a strict rotation', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);

    expect(engine.state.turnPlayerId, 'a2');
    engine.correct(1);
    expect(engine.state.turnPlayerId, 'a3');
    engine.wrong();
    expect(engine.state.turnPlayerId, 'a1');
    engine.correct(2);
    expect(engine.state.turnPlayerId, 'a2');
  });

  test('a wrong answer keeps the player red until the rotation comes back', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    engine.wrong(); // a2 غلط

    expect(engine.state.markFor('a2'), PlayerMark.wrong);
    expect(engine.state.turnPlayerId, 'a3');

    engine.wrong(); // a3 غلط، الدور لـ a1
    expect(engine.state.markFor('a2'), PlayerMark.wrong);
    expect(engine.state.turnPlayerId, 'a1');

    engine.correct(1); // a1 صح، الدور رجع لـ a2 فبتنمسح الحمرا
    expect(engine.state.turnPlayerId, 'a2');
    expect(engine.state.markFor('a2'), PlayerMark.armed);
    expect(engine.state.wrongPlayers.contains('a2'), isFalse);
  });

  test('a player who is not on turn cannot answer', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    final result = engine.buzz('a3'); // مش دوره

    expect(result.buzzedPlayerId, isNull);
    expect(result.markFor('a3'), PlayerMark.idle);
  });

  test('the player on turn can press to show they are answering', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    final result = engine.buzz('a2');

    expect(result.buzzedPlayerId, 'a2');
    expect(result.markFor('a2'), PlayerMark.buzzed);
  });

  test('the steal goes to the podium player of the other team', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    for (var i = 0; i < 3; i++) {
      engine.wrong();
    }

    expect(engine.state.phase, RoundPhase.steal);
    expect(engine.state.turnPlayerId, 'b1');
    expect(engine.state.armedPlayerIds(), {'b1'});
  });

  test('the face-off pairs the same seat number from each team', () {
    final state = freshState();

    for (final team in TeamId.values) {
      expect(state.podiumPlayer(team)?.seat, 1);
    }
    final samer = state.playersOf(TeamId.team1).first;
    expect(state.opponentOf(samer)?.id, 'b1');
    expect(state.opponentOf(samer)?.seat, samer.seat);
  });

  test('a short team wraps so there is always an opponent', () {
    final uneven = [
      Player(id: 'a1', name: 'أ١', teamId: TeamId.team1, seat: 1),
      Player(id: 'a2', name: 'أ٢', teamId: TeamId.team1, seat: 2),
      Player(id: 'b1', name: 'ب١', teamId: TeamId.team2, seat: 1),
    ];
    final state = freshState(players: uneven).copyWith(faceOffSeat: 2);

    expect(state.podiumPlayer(TeamId.team1)?.id, 'a2');
    // الفريق التاني فيه لاعب واحد، فبيرجع عليه.
    expect(state.podiumPlayer(TeamId.team2)?.id, 'b1');
  });

  test('the podium player changes every round', () {
    final engine = GameEngine(freshState());
    expect(engine.state.podiumPlayer(TeamId.team1)?.id, 'a1');
    expect(engine.state.podiumPlayer(TeamId.team2)?.id, 'b1');

    engine.giveControlTo(TeamId.team1);
    for (var i = 0; i < 3; i++) {
      engine.wrong();
    }
    engine.wrong(); // انتهت الجولة
    engine.apply(const NextRound()); // شاشة النتائج
    final next = engine.apply(const NextRound());

    expect(next.faceOffSeat, 2);
    expect(next.podiumPlayer(TeamId.team1)?.id, 'a2');
    expect(next.podiumPlayer(TeamId.team2)?.id, 'b2');
    expect(next.armedPlayerIds(), {'a2', 'b2'});
    expect(next.wrongPlayers.isEmpty, isTrue);
  });

  test('joining marks the team connected and keeps the join order', () {
    final engine = GameEngine(freshState(players: const []));
    engine.apply(const PlayerJoined('p1', 'سامر', TeamId.team1));
    engine.apply(const PlayerJoined('p2', 'ليلى', TeamId.team2));
    final result = engine.apply(const PlayerJoined('p3', 'رامي', TeamId.team1));

    expect(result.playersOf(TeamId.team1).map((p) => p.id).toList(), ['p1', 'p3']);
    // كل لاعب بياخد رقمه بفريقه لما ينضم.
    expect(result.playersOf(TeamId.team1).map((p) => p.seat).toList(), [1, 2]);
    expect(result.playersOf(TeamId.team2).map((p) => p.seat).toList(), [1]);
    expect(result.podiumPlayer(TeamId.team1)?.name, 'سامر');
    expect(result.teams[TeamId.team1]!.connected, isTrue);
    expect(result.teams[TeamId.team2]!.connected, isTrue);
  });

  test('a disconnected player is skipped in the rotation', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1); // الدور صار على a2
    engine.apply(const PlayerLeft('a3'));
    final result = engine.correct(1); // a2 جاوب، المفروض نتخطى a3

    expect(result.turnPlayerId, 'a1');
  });

  test('when the player whose turn it is drops, the turn moves on at once', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1); // الدور على a2
    expect(engine.state.turnPlayerId, 'a2');

    final result = engine.apply(const PlayerLeft('a2'));

    // ما منضل ناطرين عدّاد لاعب مش موجود — الدور راح لـ a3 فوراً.
    expect(result.phase, RoundPhase.play);
    expect(result.turnPlayerId, 'a3');
    expect(result.answerSecondsLeft, result.answerLimitSeconds);
  });

  test('losing every player marks the team disconnected', () {
    final engine = GameEngine(freshState());
    engine.apply(const PlayerLeft('a1'));
    engine.apply(const PlayerLeft('a2'));
    final result = engine.apply(const PlayerLeft('a3'));

    expect(result.teams[TeamId.team1]!.connected, isFalse);
    expect(result.teams[TeamId.team2]!.connected, isTrue);
  });

  test('a single-player team keeps its turn', () {
    final solo = [
      Player(id: 'a1', name: 'وحيد', teamId: TeamId.team1, seat: 1),
      Player(id: 'b1', name: 'وحيدة', teamId: TeamId.team2, seat: 1),
    ];
    final engine = GameEngine(freshState(players: solo));
    engine.giveControlTo(TeamId.team1);

    expect(engine.state.turnPlayerId, 'a1');
    engine.correct(1);
    expect(engine.state.turnPlayerId, 'a1');
  });

  test('a team that loses everybody mid round does not freeze the game', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    for (final id in ['a1', 'a2', 'a3']) {
      engine.apply(PlayerLeft(id));
    }

    // ما ضل حدا يضغط، بس المضيف لسا بيقدر يحكم ويكمّل الجولة.
    final afterWrong = engine.wrong();
    expect(afterWrong.phase, RoundPhase.play);

    engine.wrong();
    final steal = engine.wrong();
    expect(steal.phase, RoundPhase.steal);
    expect(steal.turnPlayerId, 'b1');

    final ended = engine.correct(1);
    expect(ended.phase, RoundPhase.roundEnd);
    expect(ended.roundWinner, TeamId.team2);
  });

  test('one player per team plays a whole round', () {
    final solo = [
      Player(id: 'a1', name: 'وحيد', teamId: TeamId.team1, seat: 1),
      Player(id: 'b1', name: 'وحيدة', teamId: TeamId.team2, seat: 1),
    ];
    final engine = GameEngine(freshState(players: solo));

    expect(engine.state.armedPlayerIds(), {'a1', 'b1'});
    engine.buzzPodium(TeamId.team1);
    engine.correct(0);
    engine.choosePlay();

    // نفس اللاعب بيضل دوره لأنه ما في غيره بالفريق.
    expect(engine.state.turnPlayerId, 'a1');
    engine.correct(1);
    expect(engine.state.turnPlayerId, 'a1');
    for (var i = 0; i < 3; i++) {
      engine.wrong();
    }
    expect(engine.state.phase, RoundPhase.steal);
    expect(engine.state.turnPlayerId, 'b1');
  });

  test('moving a player renumbers both teams', () {
    final engine = GameEngine(freshState());
    final moved = engine.apply(const PlayerMoved('a2', TeamId.team2));

    expect(moved.playersOf(TeamId.team1).map((p) => p.seat).toList(), [1, 2]);
    expect(moved.playersOf(TeamId.team1).map((p) => p.id).toList(), ['a1', 'a3']);
    expect(moved.playersOf(TeamId.team2).map((p) => p.seat).toList(), [1, 2, 3, 4]);
    expect(moved.playersOf(TeamId.team2).any((p) => p.id == 'a2'), isTrue);
  });

  test('the match start flag reaches the players', () {
    final engine = GameEngine(freshState());
    expect(engine.state.matchStarted, isFalse);

    final started = engine.apply(const StartGame());
    expect(started.matchStarted, isTrue);
    expect(started.maskedForPlayers().matchStarted, isTrue);
  });

  test('the opponent gets a full answer clock and the buzz freezes it', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.wrong();

    // بعد الغلط الدور انتقل للفريق التاني بوقت كامل.
    final passed = engine.state;
    expect(passed.phase, RoundPhase.faceOffSecond);
    expect(passed.answerSecondsLeft, passed.answerLimitSeconds);
    engine.apply(const Tick());
    engine.apply(const Tick());
    expect(engine.state.answerSecondsLeft, passed.answerLimitSeconds - 2);

    // أول ما يضغط ليجاوب بيوقف العدّاد لحد ما يحكم المضيف.
    engine.apply(const Buzz('b1', 0));
    expect(engine.state.clockPaused, true);
    engine.apply(const Tick());
    engine.apply(const Tick());
    expect(engine.state.answerSecondsLeft, passed.answerLimitSeconds - 2);

    // وبعد الحكم بيرجع يمشي.
    engine.wrong();
    expect(engine.state.clockPaused, false);
  });

  test('changing the question resets the round', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.wrong();

    final fresh = Question(
      id: 'fresh',
      text: 'سؤال تاني',
      answers: const [Answer(text: 'جواب', points: 50), Answer(text: 'جواب تاني', points: 30)],
      category: 'عام',
    );
    final state = engine.apply(ReplaceQuestion(fresh));

    expect(state.currentQuestion?.id, 'fresh');
    expect(state.phase, RoundPhase.faceOff);
    expect(state.buzzState, BuzzState.open);
    expect(state.strikes, 0);
    expect(state.wrongPlayers.isEmpty, isTrue);
  });
}
