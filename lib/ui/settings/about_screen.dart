/// «عن التطبيق» — من زر الإعدادات: الإصدار، شو بيعمل التطبيق وكيف
/// (شبكة محلية بس، بدون حسابات ولا إنترنت)، المطوّر، الموقع والمصدر،
/// والحقوق (الخطوط والأصوات)، ورخص المكتبات المفتوحة.
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../arabic_numerals.dart';
import '../components/buttons.dart';
import '../components/settings_pieces.dart';
import '../components/stage.dart';
import '../responsive.dart';
import '../theme.dart';

const String appWebsite = 'https://meen-al-atlasy-flutter.vercel.app';
const String appRepo = 'https://github.com/NKW2000/meen-al-atlasy-flutter';

class AboutScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AboutScreen({super.key, required this.onBack});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() => _version = '${info.version} (${info.buildNumber})');
          }
        })
        .catchError((_) {});
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // بدون متصفح (تلفزيون مثلاً) — الرابط مكتوب عالشاشة أصلاً.
    }
  }

  @override
  Widget build(BuildContext context) {
    final portrait = isPortrait(context);
    final body = FeudText.bodyMedium(context).copyWith(color: FeudColors.text);
    final muted = FeudText.bodyMedium(context)
        .copyWith(color: FeudColors.textMuted);

    return StageBackground(
      contentPadding: stagePadding(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                      'عن التطبيق',
                      style: FeudText.headlineSmall(context)
                          .copyWith(color: FeudColors.gold),
                    ),
                  ],
                ),
                if (!portrait)
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
                    title: 'مين الأطليسي',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _version.isEmpty
                              ? 'الإصدار …'
                              : 'الإصدار ${_version.arDigits()}',
                          style: body,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'لعبة سهرات عربية: سؤال وأجوبته مرتّبة حسب شيوعها. جهاز واحد بيصير لوح '
                          'النتائج عند المضيف، وكل لاعب بيفوت من تلفونه. فريقين، مواجهة، '
                          'أخطاء، سرقة، ونقاط.',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsCard(
                    title: 'كيف بتشتغل',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• الأجهزة بتتواصل على الواي فاي أو نقطة الاتصال نفسها — بدون إنترنت.',
                          style: body,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• ما في حسابات ولا تسجيل، وما بينبعت أي شي لأي خادم.',
                          style: body,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• اللاعبين ما بيوصلهم نص السؤال ولا الأجوبة المخفية — بس المضيف بيشوفها.',
                          style: body,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• بتقدر تستورد بنك أسئلتك الخاص من الإعدادات.',
                          style: body,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsCard(
                    title: 'المطوّر',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('عبد الرحمن نكاوة (NKW2000)', style: body),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryButton(
                                text: 'الموقع',
                                onClick: () => _open(appWebsite),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SecondaryButton(
                                text: 'المصدر على GitHub',
                                onClick: () => _open(appRepo),
                                accent: FeudColors.teal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          appWebsite,
                          style: muted,
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsCard(
                    title: 'الحقوق',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• الخطوط: Baloo Bhaijaan 2 وTajawal — رخصة SIL Open Font 1.1.',
                          style: body,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• الأصوات: تسجيلات مجانية للاستعمال التجاري من Mixkit (mixkit.co) وKenney (CC0)، مخلوطة ومعالجة لهاللعبة.',
                          style: body,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• بنك الأسئلة المرفق: من تأليف التطبيق.',
                          style: body,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SecondaryButton(
                            text: 'رخص المكتبات المفتوحة',
                            onClick: () => showLicensePage(
                              context: context,
                              applicationName: 'مين الأطليسي',
                              applicationVersion: _version,
                            ),
                            accent: FeudColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
