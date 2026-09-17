/// اختبارات Task 10: لوح المضيف (الضغط على خانة بيحكم صح، زر نهاية
/// الجولة)، شاشة اللاعب (زر / العب-مرّر / لوح حسب الحالة)، وافتتاحية
/// الجولة (ما بتنتخطّى، مرحلتين، مرة لكل جولة).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/network/player_client.dart';
import 'package:meen_al_atlasy/ui/host/host_board_screen.dart';
import 'package:meen_al_atlasy/ui/player/buzzer.dart';
import 'package:meen_al_atlasy/ui/player/play_or_pass.dart';
import 'package:meen_al_atlasy/ui/player/player_board.dart';
import 'package:meen_al_atlasy/ui/player/player_screen.dart';
import 'package:meen_al_atlasy/ui/show/round_opening.dart';
import 'package:meen_al_atlasy/ui/theme.dart';

import '../game/fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget screen, {bool portrait = false}) async {
  tester.view.physicalSize = portrait ? const Size(800, 1600) : const Size(1600, 800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(feudApp(screen));
  await tester.pump();
}

GameState _revealAll(GameState s) => s.copyWith(
      questions: [
        for (final q in s.questions)
          q.copyWith(answers: [for (final a in q.answers) a.copyWith(revealed: true)]),
      ],
    );

void main() {
  hostTurnChipTests();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HostGameBoardScreen', () {
    testWidgets('tapping a hidden slot at round end judges it correct', (tester) async {
      final taps = <int>[];
      final state = freshState().copyWith(phase: RoundPhase.roundEnd);
      await _pump(
        tester,
        HostGameBoardScreen(
          state: state,
          onCorrect: taps.add,
          onWrong: () {},
          onNextRound: () {},
        ),
      );

      expect(find.text(state.currentQuestion!.text), findsOneWidget);
      expect(find.text('اكشف الباقي'), findsOneWidget);

      // كل خانة وجهين (الأخضر تحت بشفافية صفر والكريمي فوق) — مندوس عالكريمي.
      await tester.tap(find.text(state.currentQuestion!.answers[1].text).last);
      await tester.pump();
      expect(taps, [1]);
    });

    testWidgets('once every answer is revealed the button reads the next-round label',
        (tester) async {
      var next = 0;
      final state = _revealAll(freshState()).copyWith(phase: RoundPhase.roundEnd);
      await _pump(
        tester,
        HostGameBoardScreen(
          state: state,
          onCorrect: (_) {},
          onWrong: () {},
          onNextRound: () => next++,
        ),
      );

      expect(state.isLastRound, isFalse);
      expect(find.text(state.nextButtonLabel()), findsOneWidget);
      expect(find.text('الجولة الجاية'), findsOneWidget);
      await tester.tap(find.text('الجولة الجاية'));
      await tester.pump();
      expect(next, 1);

      final last = _revealAll(freshState(questions: [board('q1')]))
          .copyWith(phase: RoundPhase.roundEnd);
      await _pump(
        tester,
        HostGameBoardScreen(state: last, onCorrect: (_) {}, onWrong: () {}, onNextRound: () {}),
      );
      expect(find.text('إنهاء اللعبة'), findsOneWidget);
    });

    testWidgets('the judge bar offers a question swap when both podium players missed',
        (tester) async {
      var swapped = false;
      final state = freshState().copyWith(phase: RoundPhase.faceOff, faceOffFailed: true);
      await _pump(
        tester,
        HostGameBoardScreen(
          state: state,
          onCorrect: (_) {},
          onWrong: () {},
          onNextRound: () {},
          onChangeQuestion: () => swapped = true,
        ),
      );

      await tester.tap(find.text('بدّل السؤال ⟳'));
      await tester.pump();
      expect(swapped, isTrue);
      expect(find.text('غلط'), findsNothing);
    });

    testWidgets('portrait lays the eight slots in one column without overflow', (tester) async {
      await _pump(
        tester,
        HostGameBoardScreen(
          state: freshState().copyWith(phase: RoundPhase.play),
          onCorrect: (_) {},
          onWrong: () {},
          onNextRound: () {},
        ),
        portrait: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('غلط'), findsOneWidget);
    });
  });

  group('PlayerScreen', () {
    final base = freshState().copyWith(matchStarted: true);
    // اللاعب a1 على المنصة بالمواجهة — مسلّح.
    final faceOff = base.copyWith(phase: RoundPhase.faceOff, buzzState: BuzzState.open);

    Widget screen(GameState? state, {String? playerId = 'a1', ConnectionStatus? status}) =>
        PlayerScreen(
          state: state,
          playerId: playerId,
          teamId: TeamId.team1,
          mark: state?.markFor(playerId) ?? PlayerMark.idle,
          status: status ?? ConnectionStatus.connected,
          onBuzz: () {},
        );

    testWidgets('an armed face-off player gets the full-screen buzzer', (tester) async {
      expect(faceOff.markFor('a1'), PlayerMark.armed);
      await _pump(tester, screen(faceOff), portrait: true);
      expect(find.byType(FullScreenBuzzer), findsOneWidget);
      expect(find.text('اضغط!'), findsOneWidget);
    });

    testWidgets('the face-off winner gets play-or-pass, teammates get the board',
        (tester) async {
      final choice = base.copyWith(
        phase: RoundPhase.playOrPass,
        faceOffWinner: TeamId.team1,
        buzzState: BuzzState.closed,
      );
      expect(choice.armedPlayerIds(), contains('a1'));
      await _pump(tester, screen(choice), portrait: true);
      expect(find.byType(PlayOrPassScreen), findsOneWidget);
      expect(find.text('العب'), findsOneWidget);
      expect(find.text('مرّر'), findsOneWidget);

      await _pump(tester, screen(choice, playerId: 'a2'), portrait: true);
      expect(find.byType(PlayerBoard), findsOneWidget);
    });

    testWidgets('otherwise the board shows the turn block and hides answer text',
        (tester) async {
      final play = base.copyWith(
        phase: RoundPhase.play,
        controllingTeam: TeamId.team1,
        turnPlayerId: 'a2',
        buzzState: BuzzState.closed,
      );
      await _pump(tester, screen(play), portrait: true);
      expect(find.byType(PlayerBoard), findsOneWidget);
      expect(find.text('دور ${play.player('a2')!.name}'), findsOneWidget);
      // الخانات المخفية عند اللاعب: رقم بنصّ البلوك وبس — بدون نص ولا نقاط.
      expect(find.text(play.currentQuestion!.answers.first.text), findsOneWidget); // الوجه الأخضر المخفي بس
      expect(find.text('٤'), findsWidgets);
    });

    testWidgets('after a wrong first face-off answer the turn block names the opponent, '
        'not the viewer', (tester) async {
      // a1 ضغط وغلط ← الدور للاعب المنصة تبع الفريق التاني (b1).
      final second = base.copyWith(
        phase: RoundPhase.faceOffSecond,
        faceOffTeam: TeamId.team2,
        buzzState: BuzzState.closed,
        wrongPlayers: {'a1'},
      );
      final opponent = second.podiumPlayer(TeamId.team2)!;

      await _pump(tester, screen(second, playerId: 'a1'), portrait: true);
      expect(find.text('دور ${opponent.name}'), findsOneWidget);
      expect(find.text('دورك'), findsNothing);

      await _pump(tester, screen(second, playerId: opponent.id), portrait: true);
      expect(find.text('دورك'), findsOneWidget);

      // بالمواجهة قبل أي ضغطة ما في «دورك» عند حدا.
      await _pump(tester, screen(faceOff, playerId: 'a3'), portrait: true);
      expect(find.text('دورك'), findsNothing);
      expect(find.text('المواجهة — أول ضغطة بتجاوب'), findsOneWidget);
    });

    testWidgets('the player whose turn it is gets an answer button that stops '
        'the clock', (tester) async {
      var buzzes = 0;
      final playing = base.copyWith(
        phase: RoundPhase.play,
        controllingTeam: TeamId.team1,
        turnPlayerId: 'a1',
        answerSecondsLeft: 10,
      );

      await _pump(
        tester,
        PlayerScreen(
          state: playing,
          playerId: 'a1',
          teamId: TeamId.team1,
          mark: playing.markFor('a1'),
          status: ConnectionStatus.connected,
          onBuzz: () => buzzes++,
        ),
        portrait: true,
      );

      expect(find.text('بجاوب'), findsOneWidget);
      await tester.tap(find.text('بجاوب'));
      expect(buzzes, 1);
    });

    testWidgets('everyone sees the answer button, but only the player on turn '
        'can press it', (tester) async {
      final playing = base.copyWith(
        phase: RoundPhase.play,
        controllingTeam: TeamId.team1,
        turnPlayerId: 'a1',
        answerSecondsLeft: 10,
      );

      // زميله بنفس الفريق: الزر مبيّن، بس الضغطة ما بتعمل إشي.
      for (final viewer in ['a2', 'b1']) {
        var buzzes = 0;
        await _pump(
          tester,
          PlayerScreen(
            state: playing,
            playerId: viewer,
            teamId: viewer.startsWith('a') ? TeamId.team1 : TeamId.team2,
            mark: playing.markFor(viewer),
            status: ConnectionStatus.connected,
            onBuzz: () => buzzes++,
          ),
          portrait: true,
        );

        expect(find.text('بجاوب'), findsOneWidget, reason: viewer);
        await tester.tap(find.text('بجاوب'));
        expect(buzzes, 0, reason: 'مش دورو — الزر مطفّي ($viewer)');
      }
    });

    testWidgets('outside the answer phases there is no button at all',
        (tester) async {
      // بين الجولات ما في جواب.
      final between = base.copyWith(phase: RoundPhase.roundEnd);
      await _pump(tester, screen(between, playerId: 'a1'), portrait: true);
      expect(find.text('بجاوب'), findsNothing);
    });

    testWidgets('once pressed it reads "answering" and cannot be pressed again',
        (tester) async {
      var buzzes = 0;
      // نفس الحالة بعد ما وصل الضغط للمضيف: العدّاد واقف واللاعب مسجّل ضاغط.
      final answering = base.copyWith(
        phase: RoundPhase.play,
        controllingTeam: TeamId.team1,
        turnPlayerId: 'a1',
        buzzedPlayerId: 'a1',
        clockPaused: true,
        answerSecondsLeft: 7,
      );

      await _pump(
        tester,
        PlayerScreen(
          state: answering,
          playerId: 'a1',
          teamId: TeamId.team1,
          mark: answering.markFor('a1'),
          status: ConnectionStatus.connected,
          onBuzz: () => buzzes++,
        ),
        portrait: true,
      );

      expect(find.text('عم تجاوب'), findsOneWidget);
      expect(find.text('بجاوب'), findsNothing);
      await tester.tap(find.text('عم تجاوب'));
      expect(buzzes, 0, reason: 'مطفّي — الضغطة وصلت أصلاً');
    });

    testWidgets('the steal and the second face-off get the button too',
        (tester) async {
      for (final phase in [RoundPhase.steal, RoundPhase.faceOffSecond]) {
        final state = phase == RoundPhase.steal
            ? base.copyWith(
                phase: phase,
                controllingTeam: TeamId.team2,
                turnPlayerId: 'a1',
                answerSecondsLeft: 10,
              )
            : base.copyWith(
                phase: phase,
                faceOffTeam: TeamId.team1,
                answerSecondsLeft: 10,
              );
        expect(state.armedPlayerIds(), contains('a1'));

        await _pump(tester, screen(state, playerId: 'a1'), portrait: true);
        expect(find.text('بجاوب'), findsOneWidget, reason: '$phase');
      }
    });

    testWidgets('the answer button is the left half of the footer row, the role '
        'block the right half — like the host board — and a long name on a '
        'narrow phone does not break it', (tester) async {
      final longName = 'عبد الرحمن المحمد ا'; // ١٩ حرف — أطول اسم مسموح
      final playing = base.copyWith(
        players: [
          Player(id: 'a1', name: longName, teamId: TeamId.team1, seat: 1),
          const Player(id: 'b1', name: 'ب١', teamId: TeamId.team2, seat: 1),
        ],
        phase: RoundPhase.play,
        controllingTeam: TeamId.team1,
        turnPlayerId: 'a1',
        answerSecondsLeft: 10,
      );

      // موبايل ضيّق.
      tester.view.physicalSize = const Size(720, 1400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(feudApp(screen(playing, playerId: 'a1')));
      await tester.pump();

      // ما في overflow ولا استثناء بالتخطيط.
      expect(tester.takeException(), isNull);

      final block = find.byType(TurnBlock);
      expect(block, findsOneWidget);
      final button = find.byType(FlatButton);
      expect(button, findsOneWidget);

      // نفس السطر ونفس الارتفاع.
      final buttonBox = tester.getRect(button);
      final blockBox = tester.getRect(block);
      expect((buttonBox.top - blockBox.top).abs(), lessThan(1));
      expect((buttonBox.height - blockBox.height).abs(), lessThan(1));

      // نصّ ونصّ: الزر عاليسار وبلوك الدور عاليمين، وعرضهم واحد.
      expect(buttonBox.right, lessThanOrEqualTo(blockBox.left));
      expect((buttonBox.width - blockBox.width).abs(), lessThan(2));
      expect(buttonBox.width, greaterThan(blockBox.width * 0.9));
    });

    testWidgets('a disconnected player sees the connection label', (tester) async {
      await _pump(
        tester,
        screen(null, status: ConnectionStatus.disconnected),
        portrait: true,
      );
      expect(find.text('انقطع الاتصال — عم نرجّعك'), findsOneWidget);
    });
  });

  group('RoundOpeningOverlay', () {
    final opening = freshState().copyWith(matchStarted: true, phase: RoundPhase.faceOff);

    testWidgets('plays intro then versus, absorbs taps, and shows once per round',
        (tester) async {
      var underneath = 0;
      Widget tree(GameState state) => Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => underneath++,
                child: const SizedBox.expand(),
              ),
              RoundOpeningOverlay(state: state),
            ],
          );
      await _pump(tester, tree(opening));

      expect(find.text('الجولة'), findsOneWidget);
      expect(find.text(roundOrdinal(1)), findsOneWidget);
      expect(find.text('${multiplierWord(1)} ×١'), findsOneWidget);

      await tester.tap(find.byType(RoundOpeningOverlay));
      await tester.pump();
      expect(underneath, 0);

      await tester.pump(const Duration(milliseconds: 2000));
      expect(find.text('ضد'), findsOneWidget);
      expect(find.text(opening.podiumPlayer(TeamId.team1)!.name), findsOneWidget);
      expect(find.text(opening.podiumPlayer(TeamId.team2)!.name), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.text('ضد'), findsNothing);
      expect(find.text('الجولة'), findsNothing);

      // نفس الجولة، نفس المرحلة (بنفس الشجرة/الحالة) — ما بتنعاد.
      await tester.pumpWidget(feudApp(tree(opening.copyWith(strikes: 1))));
      await tester.pump();
      expect(find.text('الجولة'), findsNothing);

      // جولة جديدة — بتنعاد.
      await tester.pumpWidget(feudApp(tree(opening.copyWith(currentQuestionIndex: 1))));
      await tester.pump();
      expect(find.text(roundOrdinal(2)), findsOneWidget);
    });

    testWidgets('skips versus when a podium name is missing', (tester) async {
      final lonely = opening.copyWith(
        players: [const Player(id: 'a1', name: 'سامر', teamId: TeamId.team1, seat: 1)],
      );
      await _pump(tester, RoundOpeningOverlay(state: lonely));
      expect(find.text('الجولة'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2000));
      expect(find.text('ضد'), findsNothing);
      expect(find.text('الجولة'), findsNothing);
    });

    testWidgets('does nothing outside a face-off or before the match', (tester) async {
      await _pump(tester, RoundOpeningOverlay(state: freshState()));
      expect(find.text('الجولة'), findsNothing);
      await _pump(tester, RoundOpeningOverlay(state: opening.copyWith(phase: RoundPhase.play)));
      expect(find.text('الجولة'), findsNothing);
    });
  });
}

// ---- بلوك الدور عند المضيف.
void hostTurnChipTests() {
  final base = freshState().copyWith(matchStarted: true);

  Widget board(GameState s) =>
      HostGameBoardScreen(state: s, onCorrect: (_) {}, onWrong: () {}, onNextRound: () {});

  testWidgets('the host sees who is answering in every phase', (tester) async {
    final a1 = base.podiumPlayer(TeamId.team1)!;
    final b1 = base.podiumPlayer(TeamId.team2)!;

    await _pump(tester, board(base.copyWith(phase: RoundPhase.faceOff, buzzState: BuzzState.open)));
    expect(find.text('المواجهة'), findsOneWidget);

    await _pump(tester, board(base.copyWith(phase: RoundPhase.faceOff, buzzedPlayerId: a1.id,
        faceOffTeam: TeamId.team1, buzzState: BuzzState.lockedTeam1)));
    expect(find.text(a1.name), findsOneWidget);

    // الأول غلط ← الدور للخصم.
    await _pump(tester, board(base.copyWith(phase: RoundPhase.faceOffSecond,
        faceOffTeam: TeamId.team2, buzzState: BuzzState.closed, wrongPlayers: {a1.id})));
    expect(find.text(b1.name), findsOneWidget);

    await _pump(tester, board(base.copyWith(phase: RoundPhase.play, controllingTeam: TeamId.team1,
        turnPlayerId: 'a2', buzzState: BuzzState.closed)));
    expect(find.text(base.player('a2')!.name), findsOneWidget);
  });

  testWidgets('a player pressing "I will answer" puts no extra label on the host '
      'board — the buzzer sound is the signal', (tester) async {
    final playing = base.copyWith(
      phase: RoundPhase.play,
      controllingTeam: TeamId.team1,
      turnPlayerId: 'a2',
      buzzState: BuzzState.closed,
      answerSecondsLeft: 6,
    );

    // اللاعب دوس «بجاوب» — وصل للمضيف ووقف العدّاد.
    await _pump(tester, board(playing.copyWith(buzzedPlayerId: 'a2', clockPaused: true)));

    // بدون لافتة (طلب المستخدم) — الاسم بس، والصوت بيجي من cuesFor.
    expect(find.text('عم يجاوب'), findsNothing);
    expect(find.text(base.player('a2')!.name), findsOneWidget);
  });
}
