import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/engine.dart';
import 'package:meen_al_atlasy/game/events.dart';
import 'package:meen_al_atlasy/game/models.dart';

import 'fixtures.dart';

void main() {
  test('clearing the board awards the whole pot to the controlling team', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    engine.correct(1);
    engine.correct(2);
    final result = engine.correct(3);

    expect(result.phase, RoundPhase.roundEnd);
    expect(result.roundWinner, TeamId.team1);
    expect(result.score(TeamId.team1), 100);
    expect(result.score(TeamId.team2), 0);
    expect(result.lastAward, const Award(teamId: TeamId.team1, points: 100, stolen: false));
  });

  test('three strikes open the steal for the other team', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    engine.wrong();
    engine.wrong();
    final two = engine.state;
    expect(two.phase, RoundPhase.play);
    expect(two.strikes, 2);

    final result = engine.wrong();
    expect(result.phase, RoundPhase.steal);
    expect(result.strikes, 3);
    expect(result.stealingTeam, TeamId.team2);
  });

  test('successful steal gives the pot to the stealing team', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1); // ٤٠ بالـ pot
    for (var i = 0; i < 3; i++) {
      engine.wrong();
    }
    final result = engine.correct(1); // +٣٠

    expect(result.score(TeamId.team2), 70);
    expect(result.score(TeamId.team1), 0);
    expect(result.lastAward, const Award(teamId: TeamId.team2, points: 70, stolen: true));
  });

  test('failed steal returns the pot to the controlling team', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    for (var i = 0; i < 3; i++) {
      engine.wrong();
    }
    final result = engine.wrong();

    expect(result.score(TeamId.team1), 40);
    expect(result.score(TeamId.team2), 0);
    expect(result.phase, RoundPhase.roundEnd);
  });

  test('the host reveals what is left one answer at a time after the round ends', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1); // كشف الجواب الأول
    for (var i = 0; i < 3; i++) {
      engine.wrong();
    }
    final ended = engine.wrong();

    expect(ended.phase, RoundPhase.roundEnd);
    // اللوح ما بينكشف لحاله.
    expect(ended.currentQuestion!.answers.where((a) => a.revealed).length, 1);

    final afterOne = engine.correct(2);
    expect(afterOne.currentQuestion!.answers[2].revealed, isTrue);
    // الكشف بعد الجولة ما بيزيد نقاط ولا بيغيّر الفائز.
    expect(afterOne.score(TeamId.team1), 40);
    expect(afterOne.roundWinner, TeamId.team1);
  });

  test('round multiplier scales the pot', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    for (var i = 0; i < 3; i++) {
      engine.wrong();
    }
    engine.wrong(); // نهاية الجولة الأولى
    engine.apply(const NextRound()); // شاشة النتائج
    engine.apply(const NextRound()); // الجولة الجاية

    engine.giveControlTo(TeamId.team2);
    for (var i = 0; i < 3; i++) {
      engine.wrong();
    }
    final result = engine.wrong();

    // الجولة التانية × ٢ — ٤٠ بالـ pot بتصير ٨٠
    expect(result.multiplier, 2);
    expect(result.score(TeamId.team2), 80);
  });

  test('next round resets the board state', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    engine.wrong();
    for (var i = 0; i < 3; i++) {
      engine.wrong();
    }
    engine.apply(const NextRound());
    final result = engine.apply(const NextRound());

    expect(result.currentQuestionIndex, 1);
    expect(result.phase, RoundPhase.faceOff);
    expect(result.buzzState, BuzzState.open);
    expect(result.pot, 0);
    expect(result.strikes, 0);
    expect(result.controllingTeam, isNull);
    expect(result.roundWinner, isNull);
    expect(result.gameOver, isFalse);
  });

  test('next round after the last question ends the game', () {
    final engine = GameEngine(freshState());
    engine.apply(const NextRound());
    engine.apply(const NextRound());
    final result = engine.apply(const NextRound());

    expect(result.gameOver, isTrue);
    expect(result.phase, RoundPhase.gameOver);
    expect(result.buzzState, BuzzState.closed);
  });

  test('a single-answer board ends the round straight from the face-off', () {
    final single = Question(
      id: 'solo',
      text: 'سؤال',
      answers: const [Answer(text: 'وحيد', points: 55)],
      category: 'عام',
    );
    final engine = GameEngine(freshState(questions: [single], multipliers: const [1]));
    engine.buzzPodium(TeamId.team1);
    engine.correct(0);
    final result = engine.choosePlay();

    expect(result.phase, RoundPhase.roundEnd);
    expect(result.score(TeamId.team1), 55);
  });

  test('next round shows the scoreboard before the next question', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    for (var i = 0; i < 3; i++) {
      engine.wrong();
    }
    engine.wrong(); // انتهت الجولة

    final scoreboard = engine.apply(const NextRound());
    expect(scoreboard.phase, RoundPhase.scoreboard);
    // لسا نفس السؤال — بس بتظهر النتيجة.
    expect(scoreboard.currentQuestionIndex, 0);
    expect(scoreboard.score(TeamId.team1), 40);

    final next = engine.apply(const NextRound());
    expect(next.phase, RoundPhase.faceOff);
    expect(next.currentQuestionIndex, 1);
  });

  test('the answer clock runs out as a wrong answer', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    final limit = engine.state.answerLimitSeconds;
    expect(engine.state.answerSecondsLeft, limit);

    for (var i = 0; i < limit; i++) {
      engine.apply(const Tick());
    }

    expect(engine.state.strikes, 1);
    // ودور اللاعب اللي بعده بلّش بعدّاد جديد.
    expect(engine.state.answerSecondsLeft, limit);
  });

  test('the five second choice runs out as playing the board', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.correct(0);
    expect(engine.state.choiceSecondsLeft, choiceSeconds);

    for (var i = 0; i < choiceSeconds; i++) {
      engine.apply(const Tick());
    }

    expect(engine.state.phase, RoundPhase.play);
    expect(engine.state.controllingTeam, TeamId.team1);
  });

  test('two players missing the face-off reopens the buzzer for the same pair', () {
    final onePerTeam = [
      Player(id: 'a1', name: 'أ', teamId: TeamId.team1, seat: 1),
      Player(id: 'b1', name: 'ب', teamId: TeamId.team2, seat: 1),
    ];
    final engine = GameEngine(freshState(players: onePerTeam));
    engine.buzzPodium(TeamId.team1);
    engine.wrong();
    final reopened = engine.wrong();

    expect(reopened.phase, RoundPhase.faceOff);
    expect(reopened.buzzState, BuzzState.open);
    // الاتنين رجعوا جاهزين — ما في «استنى لاعبين تانيين».
    expect(reopened.armedPlayerIds(), {'a1', 'b1'});
    expect(reopened.wrongPlayers.isEmpty, isTrue);
  });
}
