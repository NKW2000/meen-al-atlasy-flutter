/// اختبار قواعد التنبيه الصوتي — `cuesFor` دالة نقية بنفس ترتيب `when`
/// بـ`GameCues.kt`: أول قاعدة بتنطبق بس.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:meen_al_atlasy/feedback/game_cues.dart';
import 'package:meen_al_atlasy/feedback/game_feedback.dart';
import 'package:meen_al_atlasy/game/models.dart';

import '../game/fixtures.dart';

GameState _reveal(GameState s, int count) => s.copyWith(
      questions: [
        for (final q in s.questions)
          q.copyWith(answers: [
            for (final (i, a) in q.answers.indexed) a.copyWith(revealed: i < count),
          ]),
      ],
    );

void main() {
  stealCueTests();
  final base = freshState();

  test('a new award plays the win cue and nothing else', () {
    final next = _reveal(base, 4).copyWith(
      strikes: 3,
      lastAward: const Award(teamId: TeamId.team1, points: 100),
    );
    expect(cuesFor(base, next), [Cue.win]);
  });

  group('the answer button', () {
    final playing = base.copyWith(
      phase: RoundPhase.play,
      controllingTeam: TeamId.team1,
      turnPlayerId: 'a1',
      answerSecondsLeft: 8,
    );
    final pressed = playing.copyWith(buzzedPlayerId: 'a1', clockPaused: true);

    test('buzzes on the host so the host knows to listen and judge', () {
      expect(cuesFor(playing, pressed, forHost: true), [Cue.buzz]);
    });

    test('stays silent on the player devices — one room, one speaker', () {
      expect(cuesFor(playing, pressed), isEmpty);
    });

    test('does not buzz again while the clock is still paused', () {
      expect(cuesFor(pressed, pressed, forHost: true), isEmpty);
      // ثانية وقفت والعدّاد لسا واقف — ولا صوت.
      expect(
        cuesFor(pressed, pressed.copyWith(answerSecondsLeft: 7), forHost: true),
        isEmpty,
      );
    });

    test('a judgement after the press still plays its own cue', () {
      // المضيف حكم «صح» — الكشف بيغلب صوت البزر.
      final revealed = _reveal(pressed, 1).copyWith(clockPaused: false);
      expect(cuesFor(pressed, revealed, forHost: true), [Cue.reveal]);
    });
  });

  test('the same award again is silent', () {
    final awarded = base.copyWith(lastAward: const Award(teamId: TeamId.team1, points: 10));
    expect(cuesFor(awarded, awarded), isEmpty);
  });

  test('a strike plays its own numbered sound', () {
    expect(cuesFor(base.copyWith(strikes: 1), base.copyWith(strikes: 2)), [Cue.strike2]);
    expect(cuesFor(base, base.copyWith(strikes: 1)), [Cue.strike1]);
    expect(cuesFor(base.copyWith(strikes: 2), base.copyWith(strikes: 3)), [Cue.strike3]);
    expect(cuesFor(base.copyWith(strikes: 3), base.copyWith(strikes: 4)), [Cue.strike3]);
  });

  test('a face-off miss ticks wrong without a strike', () {
    expect(cuesFor(base, base.copyWith(wrongTicks: 1)), [Cue.wrong]);
  });

  test('a reveal plays reveal', () {
    expect(cuesFor(base, _reveal(base, 1)), [Cue.reveal]);
    expect(cuesFor(_reveal(base, 1), _reveal(base, 3)), [Cue.reveal]);
  });

  test('several changes at once play only the first matching rule', () {
    // خطأ + كشف بنفس اللقطة: الخطأ أول.
    expect(cuesFor(base, _reveal(base, 1).copyWith(strikes: 1)), [Cue.strike1]);
    // wrongTicks + كشف: الغلط أول.
    expect(cuesFor(base, _reveal(base, 1).copyWith(wrongTicks: 1)), [Cue.wrong]);
  });

  test('no previous state is quiet, and decreases are quiet', () {
    expect(cuesFor(null, base.copyWith(strikes: 2)), isEmpty);
    expect(cuesFor(base.copyWith(strikes: 2), base), isEmpty);
    expect(cuesFor(_reveal(base, 3), base), isEmpty);
  });

  test('strike cue for a number', () {
    expect(strikeCue(1), Cue.strike1);
    expect(strikeCue(2), Cue.strike2);
    expect(strikeCue(3), Cue.strike3);
    expect(strikeCue(9), Cue.strike3);
  });
}

// ---- السرقة (طلب المستخدم): غلط الفريق التاني = صوت الغلط تبع المواجهة،
// وصحّه = صوت كشف الجواب — مش صوت الفوز ولا صوت X.
void stealCueTests() {
  final base = freshState().copyWith(phase: RoundPhase.steal, strikes: 3);

  test('a failed steal plays the wrong sound, not win or a strike', () {
    final next = base.copyWith(
      phase: RoundPhase.roundEnd,
      wrongTicks: 1,
      lastAward: const Award(teamId: TeamId.team1, points: 100),
    );
    expect(cuesFor(base, next), [Cue.wrong]);
  });

  test('a successful steal plays its own sting', () {
    final next = _reveal(base, 1).copyWith(
      phase: RoundPhase.roundEnd,
      lastAward: const Award(teamId: TeamId.team2, points: 100, stolen: true),
    );
    expect(cuesFor(base, next), [Cue.stealWin]);
  });

  group('new moments', () {
    // حالة نظيفة — base هون تبع السرقة (strikes: 3).
    final base = freshState();
    test('time running out is its own sound, not a plain strike', () {
      // كان باقي ثانية والساعة ماشية → صار X: خلص الوقت.
      final before = base.copyWith(phase: RoundPhase.play, answerSecondsLeft: 1);
      final after = before.copyWith(strikes: 1, answerSecondsLeft: 10);
      expect(cuesFor(before, after), [Cue.timeUp]);
      // نفس الشي بس الساعة كانت واقفة (اللاعب ضاغط) → حكم عادي.
      expect(cuesFor(before.copyWith(clockPaused: true), after), [Cue.strike1]);
    });

    test('entering the steal, the choice, and the end each announce themselves', () {
      final play = base.copyWith(phase: RoundPhase.play, matchStarted: true);
      expect(cuesFor(play, play.copyWith(phase: RoundPhase.steal)), [Cue.stealOpen]);
      final faceOff = base.copyWith(phase: RoundPhase.faceOff, matchStarted: true);
      expect(cuesFor(faceOff, faceOff.copyWith(phase: RoundPhase.playOrPass)), [Cue.choicePrompt]);
      final choice = base.copyWith(phase: RoundPhase.playOrPass, matchStarted: true);
      expect(cuesFor(choice, choice.copyWith(phase: RoundPhase.play)), [Cue.choiceMade]);
      expect(cuesFor(play, play.copyWith(phase: RoundPhase.gameOver, gameOver: true)), [Cue.gameOver]);
    });

    test('joining and leaving the lobby are audible, but not mid-game', () {
      final lobby = base.copyWith(matchStarted: false);
      final more = lobby.copyWith(players: [...lobby.players, const Player(id: 'z', name: 'ز', teamId: TeamId.team1, seat: 4)]);
      expect(cuesFor(lobby, more), [Cue.join]);
      expect(cuesFor(more, lobby), [Cue.leave]);
      final game = base.copyWith(matchStarted: true);
      expect(cuesFor(game, game.copyWith(players: game.players.sublist(1))), isEmpty);
    });
  });
}
