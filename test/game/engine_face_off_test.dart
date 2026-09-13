import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/engine.dart';
import 'package:meen_al_atlasy/game/events.dart';
import 'package:meen_al_atlasy/game/models.dart';

import 'fixtures.dart';

void main() {
  faceOffClockTests();
  test('first buzz locks the other team out', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team2);
    final result = engine.buzzPodium(TeamId.team1);

    expect(result.buzzState, BuzzState.lockedTeam2);
    expect(result.faceOffTeam, TeamId.team2);
  });

  test('top answer in face-off wins control immediately', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    final result = engine.correct(0);

    expect(result.phase, RoundPhase.playOrPass);
    expect(result.faceOffWinner, TeamId.team1);
    expect(result.pot, 40);
    expect(result.score(TeamId.team1), 0); // النقاط بتنحسب بنهاية الجولة
  });

  test('lower answer gives the other team a chance to beat it', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    final result = engine.correct(2); // ٢٠ نقطة

    expect(result.phase, RoundPhase.faceOffSecond);
    expect(result.faceOffTeam, TeamId.team2);
    expect(result.faceOffLeader, TeamId.team1);
    expect(result.faceOffLeaderPoints, 20);
    expect(result.buzzState, BuzzState.closed);
  });

  test('higher second answer steals control', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.correct(2); // فريق ١ = ٢٠
    final result = engine.correct(1); // فريق ٢ = ٣٠

    expect(result.phase, RoundPhase.playOrPass);
    expect(result.faceOffWinner, TeamId.team2);
    expect(result.pot, 50);
  });

  test('lower second answer leaves control with the leader', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.correct(1); // فريق ١ = ٣٠
    final result = engine.correct(3); // فريق ٢ = ١٠

    expect(result.faceOffWinner, TeamId.team1);
    expect(result.pot, 40);
  });

  test('wrong first answer passes the face-off to the other team', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    final result = engine.wrong();

    expect(result.phase, RoundPhase.faceOffSecond);
    expect(result.faceOffTeam, TeamId.team2);
    expect(result.faceOffLeader, isNull);
  });

  test('both wrong reopens the buzzer on the same question', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.wrong();
    final result = engine.wrong();

    expect(result.phase, RoundPhase.faceOff);
    expect(result.buzzState, BuzzState.open);
    expect(result.currentQuestionIndex, 0);
    expect(result.faceOffTeam, isNull);
  });

  test('wrong first answer hands the other team a full clock', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.apply(const Tick());
    engine.apply(const Tick());
    final result = engine.wrong();

    expect(result.answerSecondsLeft, result.answerLimitSeconds);
  });

  test('every wrong answer bumps the counter that drives the sound', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    final first = engine.wrong();
    final second = engine.wrong();

    expect(first.wrongTicks, 1);
    expect(second.wrongTicks, 2);
  });

  test('both wrong moves the podium on and asks the host for a new question', () {
    final engine = GameEngine(freshState());
    final seat = engine.state.faceOffSeat;
    engine.buzzPodium(TeamId.team1);
    engine.wrong();
    final result = engine.wrong();

    expect(result.faceOffSeat, seat + 1);
    expect(result.faceOffFailed, isTrue);
  });

  test('a replaced question clears the failed face-off flag', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.wrong();
    engine.wrong();
    final result = engine.apply(ReplaceQuestion(board('q9')));

    expect(result.faceOffFailed, false);
    expect(result.phase, RoundPhase.faceOff);
  });

  test('second team correct after first was wrong takes control', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.wrong();
    final result = engine.correct(3);

    expect(result.phase, RoundPhase.playOrPass);
    expect(result.faceOffWinner, TeamId.team2);
  });

  test('buzz is ignored once the board is being played', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    final result = engine.buzzPodium(TeamId.team2);

    expect(result.buzzState, BuzzState.closed);
    expect(result.controllingTeam, TeamId.team1);
  });

  test('revealed answer cannot be judged twice', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    final result = engine.correct(0);

    expect(result.pot, 40);
    expect(result.currentQuestion!.answers[0].revealed, isTrue);
  });

  test('the face-off winner is asked to play or pass, and only that player is armed', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    final choice = engine.correct(0);

    expect(choice.phase, RoundPhase.playOrPass);
    expect(choice.faceOffWinner, TeamId.team1);
    // بس لاعب المنصة اللي كسب بيقرر.
    expect(choice.armedPlayerIds(), {'a1'});
    expect(choice.controllingTeam, isNull);
  });

  test('choosing to play keeps the board with the winner', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.correct(0);
    final result = engine.choosePlay();

    expect(result.phase, RoundPhase.play);
    expect(result.controllingTeam, TeamId.team1);
    expect(result.turnPlayerId, 'a2');
  });

  test('passing hands the board to the other team', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.correct(0);
    final result = engine.choosePass();

    expect(result.phase, RoundPhase.play);
    expect(result.controllingTeam, TeamId.team2);
    // الفريق التاني كمان بيبلّش من اللاعب اللي بعد لاعب منصته.
    expect(result.turnPlayerId, 'b2');
  });

  test('a choice outside the choosing phase is ignored', () {
    final engine = GameEngine(freshState());
    final result = engine.choosePlay();

    expect(result.phase, RoundPhase.faceOff);
    expect(result.controllingTeam, isNull);
  });
}

// ---- ساعة المواجهة (طلب المستخدم): ما في وقت قبل الضغطة؛ الضغطة بتشغّل
// وقت الجواب، وإذا خلص بدون حكم بينحسب غلط والدور للخصم بوقت كامل.

void faceOffClockTests() {
  test('nothing counts down before anyone buzzes', () {
    final engine = GameEngine(freshState());
    final started = engine.apply(const StartGame());
    expect(started.answerSecondsLeft, 0);

    for (var i = 0; i < 5; i++) {
      engine.apply(const Tick());
    }
    expect(engine.state.phase, RoundPhase.faceOff);
    expect(engine.state.buzzState, BuzzState.open);
    expect(engine.state.faceOffFailed, isFalse);
  });

  test('the buzz starts the answer clock from the answer setting', () {
    final engine = GameEngine(freshState().copyWith(answerLimitSeconds: 8));
    engine.apply(const StartGame());
    final buzzed = engine.buzzPodium(TeamId.team1);

    expect(buzzed.answerSecondsLeft, 8);
    expect(buzzed.clockPaused, isFalse);
    final ticked = engine.apply(const Tick());
    expect(ticked.answerSecondsLeft, 7);
  });

  test('running out of time after the buzz counts as wrong and hands the '
      'opponent the full answer time', () {
    final engine = GameEngine(freshState().copyWith(answerLimitSeconds: 2));
    engine.apply(const StartGame());
    engine.buzzPodium(TeamId.team1);
    engine.apply(const Tick());
    final result = engine.apply(const Tick());

    expect(result.phase, RoundPhase.faceOffSecond);
    expect(result.faceOffTeam, TeamId.team2);
    expect(result.answerSecondsLeft, 2);
    expect(result.wrongPlayers, contains(engine.state.podiumPlayer(TeamId.team1)!.id));
  });

  test('both podium players wrong reopens the buzzer with no clock', () {
    final engine = GameEngine(freshState());
    engine.apply(const StartGame());
    engine.buzzPodium(TeamId.team1);
    engine.wrong();
    final result = engine.wrong();

    expect(result.faceOffFailed, isTrue);
    expect(result.buzzState, BuzzState.open);
    expect(result.answerSecondsLeft, 0);
  });
}
