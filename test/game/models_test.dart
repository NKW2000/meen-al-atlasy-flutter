import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/engine.dart';
import 'package:meen_al_atlasy/game/events.dart';
import 'package:meen_al_atlasy/game/models.dart';

import 'fixtures.dart';

void main() {
  test('currentQuestion returns question at currentQuestionIndex', () {
    final state = freshState().copyWith(currentQuestionIndex: 1);
    expect(state.currentQuestion!.id, 'q2');
  });

  test('currentQuestion returns null when index out of range', () {
    expect(freshState(questions: const []).currentQuestion, isNull);
  });

  test('multiplier follows the round and sticks to the last value', () {
    final state = freshState(multipliers: [1, 2, 3]);
    expect(state.multiplier, 1);
    expect(state.copyWith(currentQuestionIndex: 1).multiplier, 2);
    expect(state.copyWith(currentQuestionIndex: 9).multiplier, 3);
  });

  test('active team follows the phase', () {
    final state = freshState();
    expect(
      state.copyWith(phase: RoundPhase.faceOff, faceOffTeam: TeamId.team1).activeTeam,
      TeamId.team1,
    );
    expect(
      state.copyWith(phase: RoundPhase.play, controllingTeam: TeamId.team2).activeTeam,
      TeamId.team2,
    );
    expect(
      state.copyWith(phase: RoundPhase.steal, controllingTeam: TeamId.team2).activeTeam,
      TeamId.team1,
    );
    expect(state.copyWith(phase: RoundPhase.roundEnd).activeTeam, isNull);
  });

  test('the question is hidden from players while the buzzer is open', () {
    final masked = freshState().maskedForPlayers();
    expect(masked.currentQuestion!.text, '');
  });

  test('the question never reaches a player, revealed answers do', () {
    final engine = GameEngine(freshState());
    engine.buzzPodium(TeamId.team1);
    final masked = engine.correct(0).maskedForPlayers();
    final question = masked.currentQuestion!;

    expect(question.text, '');
    expect(question.answers[0].text, 'الأول');
    expect(question.answers.skip(1).every((a) => a.text.isEmpty), isTrue);
    // ولا نقاط كمان: عند اللاعب الخانة المخفية رقم بنصّها وبس
    // (`_HiddenFace` بـ`answer_slot.dart`)، فنقاطها ما إلها شغل عنده —
    // وإرسالها كان بيلمّح لقيمة جواب لسا ما انكشف. لوح المضيف بياخد
    // الحالة كاملة مش المقنّعة، فهو بيضل يشوف النقاط.
    expect(question.answers[1].points, 0);
    expect(question.answers[0].points, 40); // المكشوف بينبعت كامل
  });

  test('the next round hides its question again', () {
    final engine = GameEngine(freshState());
    engine.giveControlTo(TeamId.team1);
    for (var i = 0; i < 3; i++) {
      engine.wrong();
    }
    engine.wrong();
    engine.apply(const NextRound()); // شاشة النتائج
    final next = engine.apply(const NextRound()).maskedForPlayers();

    expect(next.currentQuestion!.text, '');
  });

  test('GameState round-trips through JSON unchanged', () {
    final state = freshState();
    final decoded = GameState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
    );
    expect(decoded, state);
  });

  test('wire strings match the Kotlin enum names', () {
    expect(TeamId.team1.wire, 'TEAM_1');
    expect(TeamId.team2.wire, 'TEAM_2');
    expect(RoundPhase.faceOff.wire, 'FACE_OFF');
    expect(RoundPhase.playOrPass.wire, 'PLAY_OR_PASS');
    expect(BuzzState.lockedTeam1.wire, 'LOCKED_TEAM_1');
    expect(() => TeamIdX.fromWire('TEAM1'), throwsArgumentError);
  });
}
