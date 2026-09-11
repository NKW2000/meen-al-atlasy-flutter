import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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

  // ملاحظة: النسخة الأصلية (GameModelsTest.kt) بتستعمل GameEngine لتوصل
  // لهاد الحالة (buzzPodium + correct). GameEngine بيجي بـ Task 2، فهون
  // منبني نفس حالة الأجوبة يدوياً (جواب رقم ٠ مكشوف) ونتأكد إنو الإخفاء
  // (masking) شغّال صح على مستوى الموديل بس.
  test('the question never reaches a player, revealed answers do', () {
    final base = board('q1');
    final revealedFirst = base.copyWith(
      answers: [
        base.answers[0].copyWith(revealed: true),
        base.answers[1],
        base.answers[2],
        base.answers[3],
      ],
    );
    final masked =
        freshState(questions: [revealedFirst, board('q2')]).maskedForPlayers();
    final question = masked.currentQuestion!;

    expect(question.text, '');
    expect(question.answers[0].text, 'الأول');
    expect(question.answers.skip(1).every((a) => a.text.isEmpty), isTrue);
    // النقاط بتضل ظاهرة — اللوح بيعرض قيمة كل خانة مخفية.
    expect(question.answers[1].points, 30);
  });

  // نفس الملاحظة أعلاه: بدل ما نلف جولة كاملة عبر GameEngine، منتحرك
  // للسؤال التالي مباشرة عبر copyWith ونتأكد إنو نصّه محجوب من جديد.
  test('the next round hides its question again', () {
    final next = freshState().copyWith(currentQuestionIndex: 1).maskedForPlayers();
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
