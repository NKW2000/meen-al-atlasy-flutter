/// الإعدادات العامة — استيراد بنك الأسئلة وبس. باقي إعدادات اللعبة (الفرق،
/// الجولات، وقت الجواب، الأخطاء) بتتظبّط عند المضيف لما يستضيف لعبة.
///
/// منفّذ عن `BankSettingsScreen.kt` بالمشروع الأصلي (Kotlin)، وحاطّين فيه
/// كمان منطق `bankMessage`/`bankFailed` تبع `SettingsViewModel.kt` — هون
/// حالة شاشة محلية بدل ViewModel منفصل، لأنها ما لازم تعيش أطول من عمر
/// الشاشة.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/settings_repository.dart';
import '../../game/settings.dart';
import '../../questions/ai_prompt.dart';
import '../../questions/bank.dart';
import '../arabic_numerals.dart';
import '../components/buttons.dart';
import '../components/settings_pieces.dart';
import '../components/stage.dart';
import '../responsive.dart';
import '../theme.dart';

class BankSettingsScreen extends StatefulWidget {
  final SettingsRepository settings;
  final VoidCallback onBack;

  /// «عن التطبيق» — اختياري (المعرض ما بيمرّره).
  final VoidCallback? onAbout;

  const BankSettingsScreen({
    super.key,
    required this.settings,
    required this.onBack,
    this.onAbout,
  });

  @override
  State<BankSettingsScreen> createState() => _BankSettingsScreenState();
}

class _BankSettingsScreenState extends State<BankSettingsScreen> {
  String? _bankMessage;
  bool _bankFailed = false;

  GameSettings get _settings => widget.settings.current;

  Future<void> _importBank() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty) return;
    final file = files.first;
    final displayName = file.name;
    final bytes = await file.readAsBytes();
    final text = utf8.decode(bytes);
    final bankResult = await widget.settings.importBank(text, displayName);
    if (!mounted) return;
    setState(() {
      switch (bankResult) {
        case BankSuccess(:final questions):
          _bankFailed = false;
          _bankMessage =
              'تمام — انقرأ ${questions.length.ar()} سؤال من $displayName';
        case BankFailure(:final message):
          _bankFailed = true;
          _bankMessage = message;
      }
    });
  }

  /// بينسخ تعليمات شكل الملف — المضيف بيلصقها لأي ذكاء اصطناعي وبيرجع
  /// بملف جاهز للاستيراد.
  Future<void> _copyAiPrompt() async {
    await Clipboard.setData(ClipboardData(text: aiBankPrompt()));
    if (!mounted) return;
    setState(() {
      _bankFailed = false;
      _bankMessage =
          'انسخت التعليمات — الصقها بأي ذكاء اصطناعي واستورد الملف اللي بيرجعه';
    });
  }

  Future<void> _clearBank() async {
    await widget.settings.clearBank();
    if (!mounted) return;
    setState(() {
      _bankFailed = false;
      _bankMessage = 'رجعنا للبنك المرفق مع التطبيق';
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final portrait = isPortrait(context);

    return StageBackground(
      contentPadding: stagePadding(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: portrait
                  ? [
                      Row(
                        children: [
                          CartoonSurface(
                            color: FeudColors.teal,
                            borderWidth: 3,
                            corner: FeudShape.block,
                            shadow: 4,
                            onClick: widget.onBack,
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: Center(
                                child: Text(
                                  '‹',
                                  style: FeudText.titleLarge(context)
                                      .copyWith(color: FeudColors.ink),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'الإعدادات',
                            style: FeudText.headlineSmall(context)
                                .copyWith(color: FeudColors.gold),
                          ),
                        ],
                      ),
                    ]
                  : [
                      Text(
                        'الإعدادات',
                        style: FeudText.headlineSmall(context)
                            .copyWith(color: FeudColors.gold),
                      ),
                      SizedBox(
                        width: 150,
                        child: SecondaryButton(
                          text: 'رجوع',
                          onClick: widget.onBack,
                          accent: FeudColors.teal,
                        ),
                      ),
                    ],
            ),
            const SizedBox(height: 8),
            const GoldDivider(),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  SettingsCard(
                    title: 'بنك الأسئلة',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          settings.bankName != null
                              ? 'الحالي: ${settings.bankName} — ${settings.bankQuestionCount.ar()} سؤال'
                              : 'الحالي: البنك المرفق مع التطبيق',
                          style: FeudText.bodyLarge(context)
                              .copyWith(color: FeudColors.text),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryButton(
                                text: 'استيراد ملف',
                                onClick: _importBank,
                              ),
                            ),
                            if (settings.bankName != null) ...[
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 120,
                                child: SecondaryButton(
                                  text: 'حذف',
                                  onClick: _clearBank,
                                  accent: FeudColors.pink,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_bankMessage != null) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: CartoonSurface(
                              color: _bankFailed
                                  ? FeudColors.pink
                                  : FeudColors.lime,
                              borderWidth: 3,
                              corner: FeudShape.block,
                              shadow: 4,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                child: Text(
                                  _bankMessage!,
                                  style: FeudText.labelLarge(context).copyWith(
                                    color: _bankFailed
                                        ? Colors.white
                                        : FeudColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'بتقدر تستورد أسئلتك من ملف بدل الأسئلة الجاهزة. كل سؤال بدّه نص '
                          'وأجوبة، وكل جواب إله نقاط — والأعلى نقاط بياخد اللوح بالمواجهة.',
                          style: FeudText.bodyMedium(context)
                              .copyWith(color: FeudColors.textMuted),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'مش عارف تكتب الملف؟ انسخ التعليمات وأعطيها لـ ChatGPT أو أي ذكاء '
                          'اصطناعي — بيرجّعلك ملف JSON جاهز للاستيراد.',
                          style: FeudText.bodyMedium(context)
                              .copyWith(color: FeudColors.textMuted),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SecondaryButton(
                            text: 'نسخ تعليمات الذكاء الاصطناعي',
                            onClick: _copyAiPrompt,
                            accent: FeudColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onAbout != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SecondaryButton(
                        text: 'عن التطبيق',
                        onClick: widget.onAbout!,
                        accent: FeudColors.teal,
                      ),
                    ),
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
