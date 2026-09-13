/// اختبارات Task 11: لوحة النتيجة بين الجولات (الأرقام بتعدّ لحد قيمتها،
/// لافتة المتقدّم، زر المضيف/سطر اللاعب) والنتيجة النهائية (اسم الفائز،
/// أزرار المضيف).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/ui/show/game_over_screen.dart';
import 'package:meen_al_atlasy/ui/show/scoreboard_screen.dart';
import 'package:meen_al_atlasy/ui/theme.dart';

import '../game/fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget screen, {bool portrait = false}) async {
  tester.view.physicalSize = portrait ? const Size(800, 1600) : const Size(1600, 800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(feudApp(screen));
  await tester.pump();
}

GameState _scored({int team1 = 140, int team2 = 95}) => freshState().copyWith(
      teams: {
        TeamId.team1: TeamState(id: TeamId.team1, name: 'الفريق الأخضر', score: team1),
        TeamId.team2: TeamState(id: TeamId.team2, name: 'الفريق الأزرق', score: team2),
      },
      phase: RoundPhase.scoreboard,
      lastAward: const Award(teamId: TeamId.team1, points: 140),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScoreboardScreen', () {
    testWidgets('counts the scores up and names the leader', (tester) async {
      var next = 0;
      await _pump(tester, ScoreboardScreen(state: _scored(), onContinue: () => next++));

      expect(find.text('نتيجة الجولة ١/٢'), findsOneWidget);
      expect(find.text('الفريق الأخضر أخد ١٤٠'), findsOneWidget);
      // قبل العدّ الأرقام صفر.
      expect(find.text('١٤٠'), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('١٤٠'), findsOneWidget);
      expect(find.text('٩٥'), findsOneWidget);
      expect(find.text('الفريق الأخضر بالمقدمة'), findsOneWidget);

      await tester.tap(find.text('الجولة الجاية'));
      await tester.pump();
      expect(next, 1);
    });

    testWidgets('players see the waiting line, a tie says so, the last round offers the final',
        (tester) async {
      await _pump(tester, ScoreboardScreen(state: _scored(team1: 50, team2: 50)));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('بانتظار المضيف يبلّش الجولة الجاية'), findsOneWidget);
      expect(find.text('تعادل'), findsOneWidget);

      final last = _scored().copyWith(currentQuestionIndex: 1, lastAward: null);
      await _pump(tester, ScoreboardScreen(state: last, onContinue: () {}), portrait: true);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('النتيجة النهائية'), findsOneWidget);
      expect(find.text('نتيجة الجولة ٢/٢'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a steal is called out in pink', (tester) async {
      final stolen = _scored().copyWith(
        lastAward: const Award(teamId: TeamId.team2, points: 60, stolen: true),
      );
      await _pump(tester, ScoreboardScreen(state: stolen));
      expect(find.text('سرقة! الفريق الأزرق أخد ٦٠'), findsOneWidget);
    });
  });

  group('GameOverScreen', () {
    testWidgets('names the winner and offers the host both ways back', (tester) async {
      var home = 0;
      var lobby = 0;
      await _pump(
        tester,
        GameOverScreen(
          state: _scored().copyWith(gameOver: true),
          onBackHome: () => home++,
          onBackToLobby: () => lobby++,
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('النتيجة النهائية'), findsOneWidget);
      expect(find.text('فاز الفريق الأخضر'), findsOneWidget);
      expect(find.text('١٤٠'), findsOneWidget);

      await tester.tap(find.text('رجوع للوبي'));
      await tester.tap(find.text('الرئيسية'));
      await tester.pump();
      expect((home, lobby), (1, 1));
    });

    testWidgets('players get no buttons and a tie reads تعادل!', (tester) async {
      await _pump(
        tester,
        GameOverScreen(state: _scored(team1: 80, team2: 80).copyWith(gameOver: true)),
        portrait: true,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('تعادل!'), findsOneWidget);
      expect(find.text('رجوع للوبي'), findsNothing);
      expect(find.text('الرئيسية'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
