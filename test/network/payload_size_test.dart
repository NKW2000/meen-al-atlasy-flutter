/// قدّ إيش بتكبر الحزم بغرفة كبيرة؟ المضيف بيبعت لكل جهاز بكل حدث **وكل
/// ثانية** — فحجم الحزمة × عدد اللاعبين هو الحمل الحقيقي على الواي فاي،
/// وهو اللي بيأخّر وصول الضغطة. فمنقيس الاتنين: الحالة الكاملة (بالأحداث)
/// والتيك (كل ثانية).
@Tags(['network'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/game/settings.dart';
import 'package:meen_al_atlasy/network/messages.dart';

int _bytes(HostMessage m) => utf8.encode(encodeHostMessage(m)).length;

GameState _bigRoom() {
  final questions = [
    for (var i = 1; i <= GameSettings.maxRounds; i++)
      Question(
        id: 'q$i',
        text: 'اذكر شي بيعمله الناس لما يوصلوا عالبيت بعد يوم طويل بالشغل $i',
        category: 'عام',
        answers: [
          for (var a = 1; a <= 8; a++)
            Answer(text: 'جواب رقم $a لسؤال رقم $i بالبنك', points: 100 - a * 10),
        ],
      ),
  ];
  return GameState(
    questions: questions,
    multipliers: List.filled(GameSettings.maxRounds, 1),
    players: [
      for (var i = 1; i <= 18; i++)
        Player(
          id: 'ep$i',
          name: 'لاعب رقم $i',
          teamId: i.isOdd ? TeamId.team1 : TeamId.team2,
          seat: (i / 2).ceil(),
        ),
    ],
    teams: const {
      TeamId.team1: TeamState(id: TeamId.team1, name: 'الفريق الأخضر', connected: true),
      TeamId.team2: TeamState(id: TeamId.team2, name: 'الفريق الأزرق', connected: true),
    },
  );
}

void main() {
  test('the every-second packet is a few dozen bytes, not the whole game', () {
    final clock = ClockUpdate(answerSecondsLeft: 7, choiceSecondsLeft: 0);

    // ١٨ جهاز × هالحزمة كل ثانية = أقل من ٢ ك.ب/ثانية.
    expect(_bytes(clock), lessThan(128));
  });

  test('the full state packet stays small enough for a big room', () {
    final bytes = _bytes(StateUpdate(state: _bigRoom().maskedForPlayers()));

    // بتنبعت بالأحداث بس (كشف، خطأ، جولة جديدة) — مش كل ثانية.
    expect(
      bytes,
      lessThan(5 * 1024),
      reason: 'حزمة الحالة صارت $bytes بايت — ١٨ لاعب يعني ${(bytes * 18 / 1024).round()} ك.ب بكل حدث',
    );
  });

  test('rounds that are not being played carry no answers at all', () {
    final masked = _bigRoom().maskedForPlayers();

    expect(masked.questions.first.answers, hasLength(8)); // الجولة الحالية
    for (final q in masked.questions.skip(1)) {
      expect(q.answers, isEmpty);
    }
  });

  test('hidden answers ride with neither text nor points', () {
    final masked = _bigRoom().maskedForPlayers();
    final wire = encodeHostMessage(StateUpdate(state: masked));

    expect(wire, isNot(contains('اذكر شي بيعمله')));
    expect(wire, isNot(contains('جواب رقم')));
    // نقاط جواب لسا ما انكشف بتلمّح لجوابه — فما بتنبعت.
    for (final a in masked.questions.first.answers) {
      expect(a.points, 0);
    }
  });

  test('a revealed answer does carry its text and points', () {
    final state = _bigRoom();
    final revealed = state.copyWith(questions: [
      state.questions.first.copyWith(answers: [
        state.questions.first.answers.first.copyWith(revealed: true),
        ...state.questions.first.answers.skip(1),
      ]),
      ...state.questions.skip(1),
    ]);

    final first = revealed.maskedForPlayers().questions.first.answers.first;
    expect(first.text, 'جواب رقم 1 لسؤال رقم 1 بالبنك');
    expect(first.points, 90);
  });
}
