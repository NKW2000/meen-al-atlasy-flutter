/// وقت الجواب بالمواجهة: الخصم لازم ياخد وقته كامل.
///
/// شكوى من اللعب الحقيقي: «أول لاعب يغلط، العدّاد ما بيرجع للخصم وبيكمّل
/// ناقص فما بيلحق يجاوب». هون منمثّل التسلسل الحقيقي خطوة خطوة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/engine.dart';
import 'package:meen_al_atlasy/game/events.dart';
import 'package:meen_al_atlasy/game/models.dart';

import 'fixtures.dart';

void main() {
  test('the opponent gets the whole answer time after a judged wrong', () {
    final engine = GameEngine(freshState());
    final limit = engine.state.answerLimitSeconds;

    engine.buzzPodium(TeamId.team1);
    expect(engine.state.answerSecondsLeft, limit);

    // مرقت ٧ ثواني وهو عم يفكّر.
    for (var i = 0; i < 7; i++) {
      engine.apply(const Tick());
    }
    expect(engine.state.answerSecondsLeft, limit - 7);

    // المضيف حكم «غلط».
    engine.wrong();

    expect(engine.state.phase, RoundPhase.faceOffSecond);
    expect(engine.state.answerSecondsLeft, limit, reason: 'الخصم يبلّش من الأول');
    expect(engine.state.clockPaused, isFalse);
  });

  test('the opponent gets the whole answer time after a correct-but-not-top answer',
      () {
    // الحالة الأشيع بالمواجهة: الأول جاوب صح بس مش الجواب رقم ١ — الخصم
    // بياخد فرصته ليجيب أعلى. كان بياخدها بالوقت الباقي مش الكامل.
    final engine = GameEngine(freshState());
    final limit = engine.state.answerLimitSeconds;

    engine.buzzPodium(TeamId.team1);
    for (var i = 0; i < 6; i++) {
      engine.apply(const Tick());
    }
    expect(engine.state.answerSecondsLeft, limit - 6);

    engine.correct(2); // «التالت» — صح بس مش الأعلى

    expect(engine.state.phase, RoundPhase.faceOffSecond);
    expect(engine.state.faceOffTeam, TeamId.team2);
    expect(engine.state.answerSecondsLeft, limit, reason: 'الخصم يبلّش من الأول');
    expect(engine.state.clockPaused, isFalse);
  });

  test('the opponent gets the whole answer time when the clock runs out', () {
    final engine = GameEngine(freshState());
    final limit = engine.state.answerLimitSeconds;

    engine.buzzPodium(TeamId.team1);
    // خلص الوقت كله بدون جواب — بينحسب غلط لحاله.
    for (var i = 0; i < limit; i++) {
      engine.apply(const Tick());
    }

    expect(engine.state.phase, RoundPhase.faceOffSecond);
    expect(engine.state.answerSecondsLeft, limit, reason: 'الخصم يبلّش من الأول');
  });

  test('a late "wrong" tap after the clock already ran out does not burn the '
      'opponent turn', () {
    final engine = GameEngine(freshState());
    final limit = engine.state.answerLimitSeconds;
    final opponent = engine.state.podiumPlayer(TeamId.team2)!;

    engine.buzzPodium(TeamId.team1);
    // الرقم اللي كانت شاشة المضيف عليه وقت ما كان اللاعب الأول عم يجاوب.
    final turnOnScreen = engine.state.answerTurn;
    for (var i = 0; i < limit; i++) {
      engine.apply(const Tick());
    }
    // المحرك حسبها غلط لحاله وحوّل الدور للخصم.
    expect(engine.state.phase, RoundPhase.faceOffSecond);
    expect(engine.state.answerTurn, isNot(turnOnScreen));

    // المضيف دوس «غلط» بعد ما خلص الوقت (شاف اللاعب فشل) — الضغطة
    // بتحمل رقم الدور القديم فلازم تنتجاهل، مش تحسب غلط على الخصم اللي
    // لسا ما جاوب.
    engine.apply(JudgeWrong(turn: turnOnScreen));

    expect(engine.state.phase, RoundPhase.faceOffSecond,
        reason: 'الخصم لسا عندو دور');
    expect(engine.state.wrongPlayers, isNot(contains(opponent.id)));
    expect(engine.state.answerSecondsLeft, limit);
  });

  test('the opponent who actually buzzes and is judged wrong ends the face-off',
      () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    engine.wrong(); // -> faceOffSecond للخصم

    // هلق الخصم ضغط فعلاً وجاوب غلط — هاي لازم تنحسب (نفس رقم الدور).
    engine.buzzPodium(TeamId.team2);
    expect(engine.state.clockPaused, isTrue);
    engine.apply(JudgeWrong(turn: engine.state.answerTurn));

    expect(engine.state.phase, isNot(RoundPhase.faceOffSecond));
  });
}
