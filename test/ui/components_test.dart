// اختبار دخان (smoke test): كل مكوّن من مكوّنات lib/ui/components بيترسم
// جوّا feudApp() (RTL + الثيم) بدون أي استثناء.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/ui/components/answer_slot.dart';
import 'package:meen_al_atlasy/ui/components/banners.dart';
import 'package:meen_al_atlasy/ui/components/brand_logo.dart';
import 'package:meen_al_atlasy/ui/components/buttons.dart';
import 'package:meen_al_atlasy/ui/components/buzzer.dart';
import 'package:meen_al_atlasy/ui/components/confirm_dialog.dart';
import 'package:meen_al_atlasy/ui/components/countdown.dart';
import 'package:meen_al_atlasy/ui/components/fireworks.dart';
import 'package:meen_al_atlasy/ui/components/info_blocks.dart';
import 'package:meen_al_atlasy/ui/components/name_prompt_dialog.dart';
import 'package:meen_al_atlasy/ui/components/score_header.dart';
import 'package:meen_al_atlasy/ui/components/settings_pieces.dart' as settings;
import 'package:meen_al_atlasy/ui/components/stage.dart';
import 'package:meen_al_atlasy/ui/components/strikes.dart';
import 'package:meen_al_atlasy/ui/components/wordmark.dart';
import 'package:meen_al_atlasy/ui/motion/show_motion.dart';
import 'package:meen_al_atlasy/ui/theme.dart';

import '../game/fixtures.dart';

/// بيرسم [child] جوّا feudApp() بمساحة معقولة وسط الشاشة.
Future<void> pumpComponent(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(feudApp(Scaffold(body: Center(child: child))));
}

void main() {
  testWidgets('StageBackground renders without exceptions', (tester) async {
    await pumpComponent(tester, const StageBackground(child: Text('اهلا')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('CartoonSurface renders and handles taps without exceptions',
      (tester) async {
    var taps = 0;
    await pumpComponent(
      tester,
      CartoonSurface(onClick: () => taps++, child: const Text('زر')),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('زر'));
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GoldPanel and GoldDivider render without exceptions', (tester) async {
    await pumpComponent(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GoldPanel(child: Text('سؤال')),
          SizedBox(height: 8),
          GoldDivider(),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('BlockSkin and FlatShadow render without exceptions', (tester) async {
    await pumpComponent(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BlockSkin(color: FeudColors.gold, child: SizedBox(width: 80, height: 40)),
          const SizedBox(height: 8),
          FlatShadow(
            offset: 4,
            color: FeudColors.creamShadow,
            corner: FeudShape.block,
            child: const SizedBox(width: 80, height: 40),
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PrimaryButton, SecondaryButton, Pill render without exceptions',
      (tester) async {
    await pumpComponent(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(text: 'تمام', onClick: () {}),
          const SizedBox(height: 8),
          SecondaryButton(text: 'إلغاء', onClick: () {}),
          const SizedBox(height: 8),
          const Pill(text: 'شارة', color: FeudColors.lime),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('QuestionCard, StatusBanner, AwardBanner render without exceptions',
      (tester) async {
    final state = freshState();
    await pumpComponent(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const QuestionCard(round: 1, totalRounds: 4, question: 'شو الجواب؟'),
          const SizedBox(height: 8),
          const StatusBanner(text: 'دور فريق ١', accent: FeudColors.gold),
          const SizedBox(height: 8),
          AwardBanner(state: state),
          const SizedBox(height: 8),
          const BannerSpacer(),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AwardBanner scales+fades in over its Kotlin timings when an award appears',
      (tester) async {
    final base = freshState();
    final withoutAward = base;
    final withAward = base.copyWith(
      phase: RoundPhase.roundEnd,
      lastAward: const Award(teamId: TeamId.team1, points: 40),
    );

    await pumpComponent(tester, AwardBanner(state: withoutAward));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('+٤٠'), findsNothing);

    await pumpComponent(tester, AwardBanner(state: withAward));
    expect(tester.takeException(), isNull);

    // scaleIn(280ms) + fadeIn(180ms) بالكوتلن — بعد ٣٠٠ مللي ثانية لازم
    // يكون بانر النقاط ظاهر وخلص يتحرّك.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('+٤٠'), findsOneWidget);

    final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 1.0);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('RoundBlock and InfoBlock render without exceptions', (tester) async {
    await pumpComponent(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoundBlock(round: 2, totalRounds: 8),
          SizedBox(height: 8),
          InfoBlock(label: 'نقاط', value: '٤٠', accent: FeudColors.teal),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ScoreHeader and MiniScore render without exceptions', (tester) async {
    final state = freshState();
    await pumpComponent(
      tester,
      SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScoreHeader(state: state),
            const SizedBox(height: 8),
            MiniScore(state: state, teamId: TeamId.team1),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('StrikeRow and StrikeMark render without exceptions', (tester) async {
    await pumpComponent(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StrikeRow(strikes: 2),
          SizedBox(height: 8),
          StrikeMark(color: FeudColors.pink),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('StrikeFlash renders without exceptions', (tester) async {
    await pumpComponent(tester, const StrikeFlash(strikes: 0));
    expect(tester.takeException(), isNull);
    // بلّش الشاشة بغيرها حتى ننظّف أي حالة/Timer قبل ما يخلص الاختبار.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Countdown renders without exceptions', (tester) async {
    await pumpComponent(tester, const Countdown(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fireworks renders without exceptions', (tester) async {
    await pumpComponent(tester, const SizedBox(width: 300, height: 300, child: Fireworks()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('SpinningRays renders without exceptions', (tester) async {
    await pumpComponent(tester, const SizedBox(width: 300, height: 300, child: SpinningRays()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ShowScene rebuilds and its t advances with time', (tester) async {
    double? firstT;
    double? laterT;
    await pumpComponent(
      tester,
      ShowScene(
        builder: (context, t) {
          firstT ??= t;
          laterT = t;
          return Text(t.toStringAsFixed(3));
        },
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(laterT, greaterThan(firstT!));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'ShowScene restarts its single ticker (no crash) when sceneKey changes',
      (tester) async {
    double lastT = -1;
    Widget build(Object sceneKey) => ShowScene(
          sceneKey: sceneKey,
          builder: (context, t) {
            lastT = t;
            return Text(t.toStringAsFixed(3));
          },
        );

    await pumpComponent(tester, build(1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(lastT, greaterThan(0.4));

    // نفس الحالة (State) بتتحدّث — بس بمفتاح مشهد مختلف، فلازم الساعة
    // تعيد تشغيل (restart) نفس الـ Ticker من صفر بدون ما ترمي استثناء
    // (SingleTickerProviderStateMixin بيرفض ثاني createTicker).
    await pumpComponent(tester, build(2));
    expect(tester.takeException(), isNull);
    expect(lastT, closeTo(0, 1e-6));

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(lastT, greaterThan(0));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('BrandLogo, BrandLogoRow, BrandWordLine render without exceptions',
      (tester) async {
    await pumpComponent(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandLogo(em: 40, tagline: 'لعبة عائلية'),
          SizedBox(height: 8),
          BrandLogoRow(em: 30),
          SizedBox(height: 8),
          BrandWordLine(text: 'الأطليسي', em: 24),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wordmark and QuestionTile render without exceptions', (tester) async {
    await pumpComponent(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wordmark(tileSize: 70, nameSize: 28),
          SizedBox(height: 8),
          QuestionTile(size: 60),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ConfirmDialog renders and buttons work without exceptions', (tester) async {
    var confirmed = false;
    var dismissed = false;
    await pumpComponent(
      tester,
      ConfirmDialog(
        title: 'أكيد؟',
        message: 'هل تريد المتابعة؟',
        confirmText: 'أكيد',
        dismissText: 'تراجع',
        onConfirm: () => confirmed = true,
        onDismiss: () => dismissed = true,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('أكيد'));
    await tester.pump();
    await tester.tap(find.text('تراجع'));
    await tester.pump();
    expect(confirmed, isTrue);
    expect(dismissed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NamePromptDialog renders and confirms without exceptions', (tester) async {
    String? confirmedName;
    await pumpComponent(
      tester,
      NamePromptDialog(
        title: 'اسمك؟',
        initial: '',
        onConfirm: (name) => confirmedName = name,
        onDismiss: () {},
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'خالد');
    await tester.pump();
    await tester.tap(find.text('تمام'));
    await tester.pump();
    expect(confirmedName, 'خالد');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'NamePromptDialog: a leading space in an empty field does not throw and stays empty',
      (tester) async {
    await pumpComponent(
      tester,
      NamePromptDialog(
        title: 'اسمك؟',
        initial: '',
        onConfirm: (_) {},
        onDismiss: () {},
      ),
    );
    expect(tester.takeException(), isNull);

    // مسافة بحقل فاضي: النص بيصير فاضي بعد التقليم، والـ selection كانت
    // بترمي RangeError قبل التصحيح لأنها بتضل أطول من النص المقلّم.
    await tester.enterText(find.byType(TextField), ' ');
    await tester.pump();
    expect(tester.takeException(), isNull);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('SettingsCard, Stepper, MultiplierChip render without exceptions',
      (tester) async {
    var value = 3;
    await pumpComponent(
      tester,
      settings.SettingsCard(
        title: 'الإعدادات',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            settings.Stepper(
              label: 'عدد الأخطاء',
              value: value,
              min: 1,
              max: 5,
              onChange: (v) => value = v,
            ),
            const SizedBox(height: 8),
            settings.MultiplierChip(round: 2, multiplier: 2, onClick: () {}),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('BuzzerButton renders and taps without exceptions', (tester) async {
    var buzzed = false;
    await pumpComponent(
      tester,
      BuzzerButton(
        label: 'إضغط',
        subLabel: 'دورك',
        enabled: true,
        accent: FeudColors.gold,
        onClick: () => buzzed = true,
        size: 160,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('إضغط'));
    await tester.pump();
    expect(buzzed, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  group('AnswerSlotRow', () {
    testWidgets('empty slot renders without exceptions', (tester) async {
      await pumpComponent(
        tester,
        const SizedBox(
          width: 300,
          height: 56,
          child: AnswerSlotRow(position: 1, answer: null, enabled: false),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('hidden answer renders and can be tapped without exceptions',
        (tester) async {
      var tapped = false;
      await pumpComponent(
        tester,
        SizedBox(
          width: 300,
          height: 56,
          child: AnswerSlotRow(
            position: 1,
            answer: const Answer(text: 'جواب', points: 40),
            enabled: true,
            revealHiddenText: false,
            onClick: () => tapped = true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(AnswerSlotRow));
      await tester.pump();
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hidden to revealed transition animates without exceptions',
        (tester) async {
      final key = GlobalKey();
      var answer = const Answer(text: 'جواب', points: 40, revealed: false);

      Widget build() => SizedBox(
            width: 300,
            height: 56,
            child: AnswerSlotRow(
              key: key,
              position: 1,
              answer: answer,
              enabled: true,
              revealHiddenText: false,
            ),
          );

      await pumpComponent(tester, build());
      expect(tester.takeException(), isNull);
      // الوجه الكريمي (الظاهر) بيبيّن «؟ ؟ ؟» — الوجه الأخضر دايماً عنده
      // النص الحقيقي بالشجرة (زي الكوتلن بالضبط) بس مخفي (Visibility) لحد
      // ما ينكشف، فهيك 'جواب' موجودة بس مش مرسومة.
      expect(find.text('؟ ؟ ؟'), findsOneWidget);
      expect(find.text('جواب'), findsOneWidget);

      answer = const Answer(text: 'جواب', points: 40, revealed: true);
      await pumpComponent(tester, build());
      expect(tester.takeException(), isNull);

      // نتأكد إنه الحركة (٠٫٥ ثانية فليب + هزّة + نطّة نقاط) بتمشي بدون
      // استثناء لحد ما تخلص.
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);

      // بعد ما تخلص الحركة: نص «؟ ؟ ؟» اختفى، ونص الجواب الحقيقي ظاهر.
      expect(find.text('؟ ؟ ؟'), findsNothing);
      expect(find.text('جواب'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'hidden-revealed-hidden-revealed cycle reuses one ticker without exceptions',
        (tester) async {
      final key = GlobalKey();
      var answer = const Answer(text: 'جواب', points: 40, revealed: false);

      Widget build() => SizedBox(
            width: 300,
            height: 56,
            child: AnswerSlotRow(key: key, position: 1, answer: answer, enabled: true),
          );

      await pumpComponent(tester, build());
      expect(tester.takeException(), isNull);

      // كشف أول مرة.
      answer = const Answer(text: 'جواب', points: 40, revealed: true);
      await pumpComponent(tester, build());
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);

      // ترجع تختفي — ما بيصير هيك بلعبة حقيقية، بس لازم ما يكسر الساعة.
      answer = const Answer(text: 'جواب', points: 40, revealed: false);
      await pumpComponent(tester, build());
      expect(tester.takeException(), isNull);

      // كشف تاني: لازم يعيد استخدام (restart) نفس الـ ShowClock/Ticker
      // بدل ما يعمل وحدة جديدة (SingleTickerProviderStateMixin بيرفض
      // ثاني createTicker من نفس الـ State).
      answer = const Answer(text: 'جواب', points: 40, revealed: true);
      await pumpComponent(tester, build());
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);

      // بآخر لحظة، الوجه الأخضر (المكشوف) لازم يكون الظاهر مش المخفي.
      final visibilities =
          tester.widgetList<Visibility>(find.byType(Visibility)).toList();
      expect(visibilities, hasLength(2));
      expect(visibilities[0].visible, isTrue, reason: 'الوجه الأخضر ظاهر');
      expect(visibilities[1].visible, isFalse, reason: 'الوجه الكريمي مخفي');

      await tester.pumpWidget(const SizedBox());
    });
  });
}
