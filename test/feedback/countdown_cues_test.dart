/// دقّات آخر خمس ثواني: بتبلّش عند ٥، وبتسكت لما يوقف العدّاد (اللاعب دوس
/// «بجاوب») أو لما يرجع لفوق (دور لاعب تاني)، مش بس لما يخلص.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/feedback/game_cues.dart';
import 'package:meen_al_atlasy/feedback/game_feedback.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/network/player_client.dart';
import 'package:meen_al_atlasy/ui/player/player_screen.dart';
import 'package:meen_al_atlasy/ui/theme.dart';

import '../game/fixtures.dart';

/// مشغّل وهمي بيسجّل — التحميل بيخلص فوراً.
class _InstantAudio implements CueAudio {
  final List<String> log;
  final String tag;
  _InstantAudio(this.log, this.tag);
  @override
  Future<void> load(String asset) async => log.add('$tag load');
  @override
  Future<void> restart() async => log.add('$tag play');
  @override
  Future<void> stop() async => log.add('$tag stop');
  @override
  Future<void> dispose() async => log.add('$tag dispose');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> log;
  late GameFeedback feedback;
  var made = 0;

  setUp(() {
    log = [];
    made = 0;
    feedback = GameFeedback(
      configureSession: false,
      newAudio: ({required bool lowLatency}) =>
          _InstantAudio(log, lowLatency ? 'cue' : 'clock${made++}'),
    );
  });

  Widget tree({required int seconds, bool paused = false}) => GameFeedbackScope(
        feedback: feedback,
        child: CountdownCues(
          seconds: seconds,
          paused: paused,
          child: const SizedBox(),
        ),
      );

  Iterable<String> clockLog() => log.where((l) => l.startsWith('clock'));

  testWidgets('the ticking starts at five and stops the moment the clock is paused',
      (tester) async {
    await tester.pumpWidget(tree(seconds: 7));
    await tester.pump();
    expect(clockLog(), isEmpty);

    await tester.pumpWidget(tree(seconds: 5));
    await tester.pump();
    await tester.pump();
    expect(clockLog(), contains('clock0 play'));

    // اللاعب دوس «بجاوب» — العدّاد واقف على ٣، والدقّات لازم تسكت فوراً.
    await tester.pumpWidget(tree(seconds: 3, paused: true));
    await tester.pump();
    expect(clockLog(), contains('clock0 stop'));
  });

  testWidgets('a paused clock inside the window never starts ticking', (tester) async {
    await tester.pumpWidget(tree(seconds: 4, paused: true));
    await tester.pump();
    await tester.pump();

    expect(clockLog(), isEmpty);
  });

  testWidgets('when the clock resumes inside the window the ticking comes back',
      (tester) async {
    await tester.pumpWidget(tree(seconds: 3, paused: true));
    await tester.pump();
    expect(clockLog(), isEmpty);

    // المضيف حكم غلط → الدور انتقل، بس لو رجع يمشي على ٣ (مثلاً) بيدق.
    await tester.pumpWidget(tree(seconds: 3, paused: false));
    await tester.pump();
    await tester.pump();
    expect(clockLog(), contains('clock0 play'));
  });

  testWidgets('a reset to the full time silences it, and five restarts it',
      (tester) async {
    await tester.pumpWidget(tree(seconds: 4));
    await tester.pump();
    await tester.pump();
    expect(clockLog(), contains('clock0 play'));

    // الخصم أخد دوره — العدّاد رجع لـ١٠.
    await tester.pumpWidget(tree(seconds: 10));
    await tester.pump();
    expect(clockLog(), contains('clock0 stop'));

    await tester.pumpWidget(tree(seconds: 5));
    await tester.pump();
    await tester.pump();
    expect(clockLog(), contains('clock1 play'));
  });

  testWidgets('pressing «بجاوب» silences the ticking on the spot, before the host answers',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // الساعة عم تدق (٣ ثواني باقية) والدور على a1. (pumpEventQueue بتعلّق
    // جوّا testWidgets — الزمن وهمي — فمنستعمل pump.)
    feedback.startClock();
    await tester.pump();
    await tester.pump();
    expect(clockLog(), contains('clock0 play'));

    final playing = freshState().copyWith(
      matchStarted: true,
      phase: RoundPhase.play,
      controllingTeam: TeamId.team1,
      turnPlayerId: 'a1',
      answerSecondsLeft: 3,
    );
    var buzzes = 0;
    await tester.pumpWidget(feudApp(GameFeedbackScope(
      feedback: feedback,
      child: PlayerScreen(
        state: playing,
        playerId: 'a1',
        teamId: TeamId.team1,
        mark: playing.markFor('a1'),
        status: ConnectionStatus.connected,
        onBuzz: () => buzzes++,
      ),
    )));
    await tester.pump();

    await tester.tap(find.text('بجاوب'));
    await tester.pump();

    expect(buzzes, 1);
    // ما استنّينا حالة من المضيف — الصوت وقف بلحظة الضغطة.
    expect(clockLog(), contains('clock0 stop'));
  });

  test('stopClocks silences every running clock at once', () async {
    feedback.startClock();
    feedback.startClock();
    await pumpEventQueue();
    expect(clockLog().where((l) => l.endsWith('play')), hasLength(2));

    await feedback.stopClocks();

    expect(clockLog().where((l) => l.endsWith('stop')), hasLength(2));
    expect(clockLog().where((l) => l.endsWith('dispose')), hasLength(2));
  });
}
