/// لوح الأصوات بالمعرض: زر لكل تنبيه، وكل زر بيشغّل تنبيهه هو.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/demo/sound_board.dart';
import 'package:meen_al_atlasy/feedback/game_feedback.dart';
import 'package:meen_al_atlasy/ui/theme.dart';

/// مشغّل وهمي بيسجّل الملف اللي انطلب منه.
class _RecordingAudio implements CueAudio {
  final List<String> played;
  String asset = '';
  _RecordingAudio(this.played);
  @override
  Future<void> load(String a) async => asset = a;
  @override
  Future<void> restart() async => played.add(asset);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('every cue has a button and plays its own file', (tester) async {
    // شاشة طويلة حتى تبيّن كل الأزرار بدون تمرير — التمرير مش موضوع الاختبار.
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final played = <String>[];
    final feedback = GameFeedback(
      configureSession: false,
      newAudio: ({required bool lowLatency}) => _RecordingAudio(played),
    );
    await tester.pumpWidget(feudApp(
      GameFeedbackScope(feedback: feedback, child: const SoundBoardScreen()),
    ));
    await tester.pump();

    expect(cueLabels.length, Cue.values.length, reason: 'كل تنبيه إله اسم عربي');

    for (final cue in Cue.values) {
      final label = cueLabels[cue]!;
      played.clear();
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump();
      expect(played, ['sounds/sfx_${cue.name}.mp3'], reason: cue.name);
    }
    // أنماط الاهتزاز مؤقّتات قصيرة — منخلّيها تخلص قبل ما ينتهي الاختبار.
    await tester.pump(const Duration(seconds: 2));
  });
}
