/// لوح الأصوات — بالمعرض بس: زر لكل تنبيه باللعبة حتى تسمعهن كلهن على
/// الجهاز وتقارن بينهن بدون ما تلعب جولة كاملة.
library;

import 'package:flutter/material.dart';

import '../feedback/game_feedback.dart';
import '../ui/arabic_numerals.dart';
import '../ui/components/stage.dart';
import '../ui/theme.dart';

/// اسم عربي لكل تنبيه — نفس ترتيب [Cue].
const Map<Cue, String> cueLabels = {
  Cue.reveal: 'كشف جواب',
  Cue.strike1: 'خطأ ١',
  Cue.strike2: 'خطأ ٢',
  Cue.strike3: 'خطأ ٣',
  Cue.wrong: 'غلط بالمواجهة',
  Cue.win: 'فوز الجولة',
  Cue.buzz: 'ضغطة الزر',
  Cue.clock: 'آخر ٥ ثواني',
  Cue.timeUp: 'خلص الوقت',
  Cue.stealOpen: 'فرصة سرقة',
  Cue.stealWin: 'سرقة ناجحة',
  Cue.choicePrompt: 'العب أو مرّر؟',
  Cue.choiceMade: 'اتخذ القرار',
  Cue.faceOffOpen: 'الزر مفتوح',
  Cue.intro: 'افتتاحية التطبيق',
  Cue.roundStart: 'بداية الجولة',
  Cue.versus: 'استعدوا',
  Cue.scoreCount: 'عدّ النقاط',
  Cue.crown: 'التاج',
  Cue.banner: 'لافتة المقدمة',
  Cue.gameOver: 'نهاية اللعبة',
  Cue.fireworks: 'ألعاب نارية',
  Cue.tap: 'نقرة زر',
  Cue.join: 'انضم لاعب',
  Cue.leave: 'راح لاعب',
  Cue.connected: 'اتصل بالغرفة',
  Cue.kicked: 'انطرد',
  Cue.teamSwitch: 'بدّل الفريق',
  Cue.error: 'خطأ',
};

/// المجموعات بالشاشة — حتى تكون اللستة مقروءة، مش ٢٩ زر ورا بعض.
const List<(String, List<Cue>)> _groups = [
  ('أحداث اللعبة', [
    Cue.faceOffOpen, Cue.buzz, Cue.reveal, Cue.wrong, Cue.strike1, Cue.strike2, Cue.strike3,
    Cue.clock, Cue.timeUp, Cue.stealOpen, Cue.stealWin, Cue.choicePrompt, Cue.choiceMade, Cue.win,
  ]),
  ('الحركات والشاشات', [
    Cue.intro, Cue.roundStart, Cue.versus, Cue.scoreCount, Cue.crown, Cue.banner,
    Cue.gameOver, Cue.fireworks,
  ]),
  ('اللوبي والواجهة', [
    Cue.tap, Cue.join, Cue.leave, Cue.connected, Cue.kicked, Cue.teamSwitch, Cue.error,
  ]),
];

class SoundBoardScreen extends StatefulWidget {
  const SoundBoardScreen({super.key});

  @override
  State<SoundBoardScreen> createState() => _SoundBoardScreenState();
}

class _SoundBoardScreenState extends State<SoundBoardScreen> {
  Cue? _last;
  int? _clockStream;

  /// محفوظ من `didChangeDependencies` — البحث عن الأسلاف وقت `dispose` ممنوع.
  GameFeedback? _feedback;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _feedback = GameFeedbackScope.maybeOf(context);
  }

  void _play(Cue cue) {
    final feedback = _feedback;
    setState(() => _last = cue);
    if (feedback == null) return;
    if (cue == Cue.clock) {
      // الساعة مجرى مستقل — منوقّف اللي قبله ومنبلّش من أوله.
      final old = _clockStream;
      if (old != null) feedback.stopStream(old);
      _clockStream = feedback.startClock();
      return;
    }
    feedback.play(cue);
  }

  @override
  void dispose() {
    final old = _clockStream;
    if (old != null) _feedback?.stopStream(old);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _last;
    return StageBackground(
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 60),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'لوح الأصوات',
                    style: FeudText.headlineSmall(context).copyWith(color: FeudColors.gold),
                  ),
                ),
                if (last != null)
                  Text(
                    '${cueLabels[last]} · sfx_${last.name}',
                    style: FeudText.labelMedium(context).copyWith(color: FeudColors.textMuted),
                    textDirection: TextDirection.ltr,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${Cue.values.length.ar()} صوت — دوس على أي واحد لتسمعه',
              style: FeudText.bodyMedium(context).copyWith(color: FeudColors.textMuted),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  for (final (title, cues) in _groups) ...[
                    Text(
                      title,
                      style: FeudText.titleMedium(context).copyWith(color: FeudColors.cream),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cue in cues)
                          CartoonSurface(
                            color: cue == last ? FeudColors.gold : FeudColors.stageAlt,
                            borderWidth: 3,
                            corner: 12,
                            shadow: 3,
                            onClick: () => _play(cue),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cueLabels[cue] ?? cue.name,
                                    style: FeudText.labelLarge(context).copyWith(
                                      color: cue == last ? FeudColors.ink : FeudColors.cream,
                                    ),
                                  ),
                                  Text(
                                    cue.name,
                                    textDirection: TextDirection.ltr,
                                    style: FeudText.labelSmall(context).copyWith(
                                      color: cue == last
                                          ? FeudColors.ink.withValues(alpha: 0.7)
                                          : FeudColors.textFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
