/// إعدادات المضيف — أول شاشة بيشوفها لما يضغط «استضافة لعبة»: أسماء
/// الفريقين، بنك الأسئلة، عدد الجولات ومضاعفاتها، وقت الجواب، وعدد
/// الأخطاء اللي بتفتح السرقة. بعدها بيكمّل عاللوبي.
///
/// الشاشة الوحيدة اللي بتتمرّر بكل التطبيق — جسمها طويل بالوضعين.
///
/// منفّذ عن `HostSettingsScreen.kt` بالمشروع الأصلي (Kotlin). ملاحظة:
/// هاي الشاشة إلها عناصر خاصة فيها (`SettingRow`/`MultiplierTile`/
/// `NameLine`/`StepKey`) بالأصل الكوتلن — مش نفس `Stepper`/`MultiplierChip`
/// المشتركة بـ`components/SettingsPieces.kt` (شكل مختلف شوي: خانة واحدة
/// محاطة بإطار بدل زرّين لحالهم) — فمنفّذينها هون بالضبط متل ما هيّي،
/// بدل ما نغصب الشاشة تستعمل المكوّن المشترك.
library;

import 'package:flutter/material.dart' hide Stepper;

import '../../game/models.dart';
import '../../game/settings.dart';
import '../arabic_numerals.dart';
import '../components/buttons.dart';
import '../components/name_prompt_dialog.dart';
import '../components/stage.dart';
import '../components/strikes.dart';
import '../theme.dart';

class HostSettingsScreen extends StatefulWidget {
  final GameSettings settings;
  final ValueChanged<GameSettings> onSettingsChange;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final (int, int) answerBounds;
  final int matchingQuestions;

  const HostSettingsScreen({
    super.key,
    required this.settings,
    required this.onSettingsChange,
    required this.onBack,
    required this.onContinue,
    this.answerBounds = const (GameSettings.minAnswersBound, GameSettings.maxAnswersBound),
    this.matchingQuestions = 0,
  });

  @override
  State<HostSettingsScreen> createState() => _HostSettingsScreenState();
}

class _HostSettingsScreenState extends State<HostSettingsScreen> {
  TeamId? _renamingTeam;
  bool _renamingRoom = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _clampToBounds());
  }

  @override
  void didUpdateWidget(covariant HostSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.answerBounds != widget.answerBounds) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _clampToBounds());
    }
  }

  // البنك بيحكم الفلتر: إذا تغيّر، منرجّع الأرقام لحدوده.
  void _clampToBounds() {
    if (!mounted) return;
    final (lowBound, highBound) = widget.answerBounds;
    final settings = widget.settings;
    final low = settings.minAnswers.clamp(lowBound, highBound).toInt();
    final high = settings.maxAnswers.clamp(low, highBound).toInt();
    if (low != settings.minAnswers || high != settings.maxAnswers) {
      widget.onSettingsChange(settings.copyWith(minAnswers: low, maxAnswers: high));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _DesignHostSettings(
        settings: widget.settings,
        answerBounds: widget.answerBounds,
        matchingQuestions: widget.matchingQuestions,
        onSettingsChange: widget.onSettingsChange,
        onBack: widget.onBack,
        onContinue: widget.onContinue,
        onRenameRoom: () => setState(() => _renamingRoom = true),
        onRenameTeam: (teamId) => setState(() => _renamingTeam = teamId),
      ),
      if (_renamingRoom)
        NamePromptDialog(
          title: 'اسم الغرفة',
          initial: widget.settings.roomName,
          maxLength: GameSettings.maxTeamName,
          onConfirm: (name) {
            widget.onSettingsChange(widget.settings.copyWith(roomName: name));
            setState(() => _renamingRoom = false);
          },
          onDismiss: () => setState(() => _renamingRoom = false),
        ),
      if (_renamingTeam != null)
        NamePromptDialog(
          title: 'اسم الفريق',
          initial: widget.settings.teamName(_renamingTeam!),
          maxLength: GameSettings.maxTeamName,
          onConfirm: (name) {
            final teamId = _renamingTeam!;
            widget.onSettingsChange(widget.settings.copyWith(
              teamNames: {...widget.settings.teamNames, teamId: name},
            ));
            setState(() => _renamingTeam = null);
          },
          onDismiss: () => setState(() => _renamingTeam = null),
        ),
    ]);
  }
}

/// نفس التصميم بالوضعين: شريط علوي، جسم بيتمرّر، وشريط سفلي.
class _DesignHostSettings extends StatelessWidget {
  final GameSettings settings;
  final (int, int) answerBounds;
  final int matchingQuestions;
  final ValueChanged<GameSettings> onSettingsChange;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onRenameRoom;
  final ValueChanged<TeamId> onRenameTeam;

  const _DesignHostSettings({
    required this.settings,
    required this.answerBounds,
    required this.matchingQuestions,
    required this.onSettingsChange,
    required this.onBack,
    required this.onContinue,
    required this.onRenameRoom,
    required this.onRenameTeam,
  });

  @override
  Widget build(BuildContext context) {
    final (lowBound, highBound) = answerBounds;
    final perRound = settings.multipliersForRounds();

    return ColoredBox(
      color: FeudColors.stage,
      child: SafeArea(
        child: Column(
          children: [
            // شريط علوي.
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: FeudColors.ink, width: 4)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                children: [
                  CartoonSurface(
                    color: FeudColors.teal,
                    borderWidth: 3,
                    corner: FeudShape.block,
                    shadow: 4,
                    onClick: onBack,
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Center(
                        child:
                            Text('‹', style: FeudText.titleLarge(context).copyWith(color: FeudColors.ink)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'إعدادات اللعبة',
                    style: FeudText.headlineSmall(context).copyWith(color: FeudColors.gold),
                  ),
                ],
              ),
            ),

            // بالعرضي منحدّد عرض العمود حتى ما تصير الخانات شريط طويل فاضي.
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ---- الأسماء
                        _SectionLabel('الأسماء'),
                        const SizedBox(height: 10),
                        _NameLine(
                          label: 'الغرفة',
                          name: settings.roomName,
                          color: FeudColors.gold,
                          ink: FeudColors.ink,
                          onRename: onRenameRoom,
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < TeamId.values.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _NameLine(
                            label: 'فريق ${(i + 1).ar()}',
                            name: settings.teamName(TeamId.values[i]),
                            color: TeamId.values[i].color(),
                            ink: TeamId.values[i].inkColor(),
                            onRename: () => onRenameTeam(TeamId.values[i]),
                          ),
                        ],

                        const SizedBox(height: 22),

                        // ---- الجولات
                        _SectionLabel('الجولات'),
                        const SizedBox(height: 12),
                        _SettingRow(
                          label: 'عدد الجولات',
                          value: settings.rounds.ar(),
                          onMinus: () => onSettingsChange(settings.copyWith(
                            rounds: (settings.rounds - 1)
                                .clamp(GameSettings.minRounds, GameSettings.maxRounds)
                                .toInt(),
                          )),
                          onPlus: () => onSettingsChange(settings.copyWith(
                            rounds: (settings.rounds + 1)
                                .clamp(GameSettings.minRounds, GameSettings.maxRounds)
                                .toInt(),
                          )),
                        ),
                        const SizedBox(height: 12),
                        for (var row = 0; row * 4 < perRound.length; row++) ...[
                          if (row > 0) const SizedBox(height: 8),
                          Row(
                            children: [
                              for (var col = 0; col < 4; col++) ...[
                                if (col > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: row * 4 + col < perRound.length
                                      ? _MultiplierTile(
                                          round: row * 4 + col + 1,
                                          multiplier: perRound[row * 4 + col],
                                          onClick: () {
                                            final index = row * 4 + col;
                                            final next = List<int>.of(perRound);
                                            next[index] = next[index] >= 4 ? 1 : next[index] + 1;
                                            onSettingsChange(settings.copyWith(multipliers: next));
                                          },
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'دوس على الجولة تبدّل مضاعفها',
                          style: FeudText.labelMedium(context).copyWith(color: FeudColors.textFaint),
                        ),

                        const SizedBox(height: 22),

                        // ---- الوقت والأخطاء
                        _SectionLabel('الوقت والأخطاء'),
                        const SizedBox(height: 12),
                        _SettingRow(
                          label: 'ثواني المواجهة (قبل الضغط)',
                          value: settings.faceOffSeconds.ar(),
                          onMinus: () => onSettingsChange(settings.copyWith(
                            faceOffSeconds: (settings.faceOffSeconds - 1)
                                .clamp(GameSettings.minFaceOffSeconds, GameSettings.maxFaceOffSeconds)
                                .toInt(),
                          )),
                          onPlus: () => onSettingsChange(settings.copyWith(
                            faceOffSeconds: (settings.faceOffSeconds + 1)
                                .clamp(GameSettings.minFaceOffSeconds, GameSettings.maxFaceOffSeconds)
                                .toInt(),
                          )),
                        ),
                        const SizedBox(height: 12),
                        _SettingRow(
                          label: 'ثواني الجواب',
                          value: settings.answerSeconds.ar(),
                          onMinus: () => onSettingsChange(settings.copyWith(
                            answerSeconds: (settings.answerSeconds - 5)
                                .clamp(GameSettings.minAnswerSeconds, GameSettings.maxAnswerSeconds)
                                .toInt(),
                          )),
                          onPlus: () => onSettingsChange(settings.copyWith(
                            answerSeconds: (settings.answerSeconds + 5)
                                .clamp(GameSettings.minAnswerSeconds, GameSettings.maxAnswerSeconds)
                                .toInt(),
                          )),
                        ),
                        const SizedBox(height: 12),
                        _SettingRow(
                          label: 'ثواني «العب أو تمرير»',
                          value: settings.choiceSeconds.ar(),
                          onMinus: () => onSettingsChange(settings.copyWith(
                            choiceSeconds: (settings.choiceSeconds - 1)
                                .clamp(GameSettings.minChoiceSeconds, GameSettings.maxChoiceSeconds)
                                .toInt(),
                          )),
                          onPlus: () => onSettingsChange(settings.copyWith(
                            choiceSeconds: (settings.choiceSeconds + 1)
                                .clamp(GameSettings.minChoiceSeconds, GameSettings.maxChoiceSeconds)
                                .toInt(),
                          )),
                        ),
                        const SizedBox(height: 12),
                        _SettingRow(
                          label: 'أخطاء تفتح السرقة',
                          value: settings.strikesToSteal.ar(),
                          onMinus: () => onSettingsChange(settings.copyWith(
                            strikesToSteal: (settings.strikesToSteal - 1)
                                .clamp(GameSettings.minStrikes, GameSettings.maxStrikes)
                                .toInt(),
                          )),
                          onPlus: () => onSettingsChange(settings.copyWith(
                            strikesToSteal: (settings.strikesToSteal + 1)
                                .clamp(GameSettings.minStrikes, GameSettings.maxStrikes)
                                .toInt(),
                          )),
                        ),

                        const SizedBox(height: 22),

                        // ---- تصفية الأسئلة
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _SectionLabel('تصفية الأسئلة')),
                            Pill(
                              text: '${matchingQuestions.ar()} سؤال مطابق',
                              color: matchingQuestions >= settings.rounds
                                  ? FeudColors.lime
                                  : FeudColors.pink,
                              textColor: matchingQuestions >= settings.rounds
                                  ? FeudColors.ink
                                  : FeudColors.cream,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SettingRow(
                          label: 'أقل عدد أجوبة',
                          value: settings.minAnswers.ar(),
                          onMinus: () => onSettingsChange(settings.copyWith(
                            minAnswers: (settings.minAnswers - 1).clamp(lowBound, highBound).toInt(),
                          )),
                          onPlus: () => onSettingsChange(settings.copyWith(
                            minAnswers: (settings.minAnswers + 1)
                                .clamp(lowBound, settings.maxAnswers)
                                .toInt(),
                          )),
                        ),
                        const SizedBox(height: 12),
                        _SettingRow(
                          label: 'أكثر عدد أجوبة',
                          value: settings.maxAnswers.ar(),
                          onMinus: () => onSettingsChange(settings.copyWith(
                            maxAnswers: (settings.maxAnswers - 1)
                                .clamp(settings.minAnswers, highBound)
                                .toInt(),
                          )),
                          onPlus: () => onSettingsChange(settings.copyWith(
                            maxAnswers: (settings.maxAnswers + 1).clamp(lowBound, highBound).toInt(),
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // شريط سفلي.
            Container(
              width: double.infinity,
              color: FeudColors.panelDark,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: 'كمّل للوبي',
                      onClick: onContinue,
                      color: FeudColors.lime,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// عنوان قسم صغير بالذهبي.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: FeudText.labelLarge(context).copyWith(color: FeudColors.gold));
}

/// سطر اسم: تسمية صغيرة، الاسم بلون، وزر قلم.
class _NameLine extends StatelessWidget {
  final String label;
  final String name;
  final Color color;
  final Color ink;
  final VoidCallback onRename;

  const _NameLine({
    required this.label,
    required this.name,
    required this.color,
    required this.ink,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: FeudText.labelMedium(context).copyWith(color: FeudColors.textMuted),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CartoonSurface(
            color: color,
            borderWidth: 3,
            corner: FeudShape.block,
            shadow: 4,
            onClick: onRename,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FeudText.titleSmall(context).copyWith(color: ink),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        CartoonSurface(
          color: FeudColors.stageAlt,
          borderWidth: 3,
          corner: FeudShape.block,
          shadow: 0,
          onClick: onRename,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: Text('✎', style: FeudText.titleSmall(context).copyWith(color: FeudColors.cream)),
            ),
          ),
        ),
      ],
    );
  }
}

/// سطر إعداد: التسمية عاليمين وعدّاد − قيمة + عالشمال.
class _SettingRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  // نفس `valueWidth: Dp = 52.dp` بكوتلن — ما في نداء بيغيّرها هونيك
  // كمان، فمثبّتينها هون بدل ما نعرّف بارامتر ما حدا بيستعمله.
  static const double _valueWidth = 52;

  const _SettingRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(label, style: FeudText.bodyMedium(context).copyWith(color: FeudColors.cream)),
        ),
        const SizedBox(width: 12),
        CartoonSurface(
          color: FeudColors.stageAlt,
          borderWidth: 3,
          corner: FeudShape.block,
          shadow: 4,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FeudShape.block),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepKey(symbol: '−', onClick: onMinus),
                  SizedBox(
                    width: _valueWidth,
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: FeudText.titleLarge(context).copyWith(color: FeudColors.gold),
                    ),
                  ),
                  _StepKey(symbol: '+', onClick: onPlus),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// مربّع ذهبي بعلامة زائد أو ناقص.
class _StepKey extends StatelessWidget {
  final String symbol;
  final VoidCallback onClick;

  const _StepKey({required this.symbol, required this.onClick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClick,
      child: Container(
        width: 40,
        height: 40,
        color: FeudColors.gold,
        alignment: Alignment.center,
        child: Text(symbol, style: FeudText.titleLarge(context).copyWith(color: FeudColors.ink)),
      ),
    );
  }
}

/// مربّع مضاعف الجولة.
class _MultiplierTile extends StatelessWidget {
  final int round;
  final int multiplier;
  final VoidCallback onClick;

  const _MultiplierTile({
    required this.round,
    required this.multiplier,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (multiplier) {
      1 => FeudColors.stage,
      2 => FeudColors.teal,
      3 => FeudColors.lime,
      _ => FeudColors.gold,
    };
    final ink = multiplier == 1 ? FeudColors.cream : FeudColors.ink;

    return CartoonSurface(
      color: color,
      borderWidth: 3,
      corner: FeudShape.block,
      shadow: 4,
      onClick: onClick,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('×${multiplier.ar()}', style: FeudText.titleLarge(context).copyWith(color: ink)),
            const SizedBox(height: 4),
            Text(
              'جولة ${round.ar()}',
              style: FeudText.labelSmall(context).copyWith(color: ink.withValues(alpha: 0.65)),
            ),
          ],
        ),
      ),
    );
  }
}
