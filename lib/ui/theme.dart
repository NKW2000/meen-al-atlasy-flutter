/// ألوان التصميم الكرتوني: حدود سودا سميكة، ظلال صلبة، وألوان مشبعة على
/// خلفية بنفسجية. [FeudColors.ink] هو لون الحد والظل بكل مكان.
///
/// منفّذ عن `theme/Theme.kt` بالمشروع الأصلي (Kotlin) — كل قيمة لون أو
/// قياس منسوخة بالحرف.
library;

import 'package:flutter/material.dart';

import 'responsive.dart';

/// قياسات الشكل: زاوية وحدة لكل البلوكات بالتطبيق.
abstract final class FeudShape {
  /// زاوية كل بلوك — كرت، خانة جواب، زر، حقل.
  static const double block = 16;

  /// الشرائح المدوّرة (Pill).
  static const double pill = 999;
}

abstract final class FeudColors {
  static const ink = Color(0xFF140626);
  static const canvas = Color(0xFF170A31);
  static const stage = Color(0xFF2A1258);
  static const stageAlt = Color(0xFF3A1C6E);
  static const panelDark = Color(0xFF241048);
  static const gold = Color(0xFFFFD23F);
  static const pink = Color(0xFFFF5470);
  static const teal = Color(0xFF2BE0D6);
  static const lime = Color(0xFF9BE564);
  static const cream = Color(0xFFFFF6E5);

  static const team1 = Color(0xFF37C46B);
  static const team1Ink = Color(0xFF0B2E18);
  static const team2 = Color(0xFF2D9CFF);
  static const team2Ink = Color(0xFF08213D);

  static const text = cream;
  static const textSoft = Color(0xFFDCCEFB);
  static const textMuted = Color(0xFFC9B6EE);
  static const textFaint = Color(0xFF8B76C4);
  static const outlineSoft = Color(0xFF6E5A9C);

  // ظلال مسطّحة (تحت العنصر مباشرة) — نفس ألوان كروت التصميم الطولي.
  static const creamShadow = Color(0xFFB9A88E);
  static const strikeShadow = Color(0xFFB02F45);
  static const team1Shadow = Color(0xFF16803C);
  static const limeShadow = Color(0xFF5F9E33);
  static const goldShadow = Color(0xFFB98A12);

  // أسماء قديمة بيستعملها باقي الكود.
  static const deepNavy = canvas;
  static const strike = pink;
  static const goldDim = Color(0xFFA78FD8);
}

/// ألوان الفرق — نفس اللون بكل الشاشات حتى يميّز اللاعب فريقه بسرعة.
abstract final class TeamColors {
  static const team1 = FeudColors.team1;
  static const team2 = FeudColors.team2;
}

abstract final class FeudBrushes {
  static const stage = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [FeudColors.stageAlt, FeudColors.stage, FeudColors.canvas],
  );

  /// الشريط المخطط اللي فوق الشاشات — ذهبي/وردي/فيروزي.
  static const stripes = [FeudColors.gold, FeudColors.pink, FeudColors.teal];
}

/// خط العناوين — Baloo Bhaijaan 2.
const String displayFontFamily = 'BalooBhaijaan2';

/// خط النصوص — Tajawal.
const String bodyFontFamily = 'Tajawal';

TextStyle _display(int size) {
  final lineHeight = (size * 1.2).toInt();
  return TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: FontWeight.w800,
    fontSize: size.toDouble(),
    height: lineHeight / size,
  );
}

TextStyle _body(int size, {FontWeight weight = FontWeight.w500}) {
  final lineHeight = (size * 1.45).toInt();
  return TextStyle(
    fontFamily: bodyFontFamily,
    fontWeight: weight,
    fontSize: size.toDouble(),
    height: lineHeight / size,
  );
}

// مقياسين بنفس الخطوط والأوزان: الأفقي مضغوط لأنه كل شي لازم يوقع
// بشاشة وحدة بدون تمرير، والطولي أكبر لأنه الموبايل بالإيد وبيتمرّر.

/// مقياس الأنماط — نفس `Typography` بالكوتلن. [BuildContext] بيحدد
/// الأفقي/الطولي.
class FeudText {
  const FeudText._();

  static TextStyle displayLarge(BuildContext context) =>
      isPortrait(context) ? _display(54) : _display(42);
  static TextStyle displayMedium(BuildContext context) =>
      isPortrait(context) ? _display(44) : _display(34);
  static TextStyle displaySmall(BuildContext context) =>
      isPortrait(context) ? _display(36) : _display(28);
  static TextStyle headlineLarge(BuildContext context) =>
      isPortrait(context) ? _display(32) : _display(25);
  static TextStyle headlineMedium(BuildContext context) =>
      isPortrait(context) ? _display(28) : _display(22);
  static TextStyle headlineSmall(BuildContext context) =>
      isPortrait(context) ? _display(24) : _display(19);
  static TextStyle titleLarge(BuildContext context) =>
      isPortrait(context) ? _display(22) : _display(18);
  static TextStyle titleMedium(BuildContext context) =>
      isPortrait(context) ? _display(19) : _display(15);
  static TextStyle titleSmall(BuildContext context) =>
      isPortrait(context) ? _display(17) : _display(13);
  static TextStyle bodyLarge(BuildContext context) =>
      isPortrait(context) ? _body(17) : _body(13);
  static TextStyle bodyMedium(BuildContext context) =>
      isPortrait(context) ? _body(15) : _body(11);
  static TextStyle labelLarge(BuildContext context) => isPortrait(context)
      ? _body(14, weight: FontWeight.w800)
      : _body(11, weight: FontWeight.w800);
  static TextStyle labelMedium(BuildContext context) => isPortrait(context)
      ? _body(13, weight: FontWeight.w700)
      : _body(10, weight: FontWeight.w700);
  static TextStyle labelSmall(BuildContext context) => isPortrait(context)
      ? _body(12, weight: FontWeight.w700)
      : _body(9, weight: FontWeight.w700);
}

final ColorScheme _feudColorScheme = ColorScheme.dark(
  primary: FeudColors.gold,
  onPrimary: FeudColors.ink,
  secondary: FeudColors.teal,
  onSecondary: FeudColors.ink,
  tertiary: FeudColors.pink,
  surface: FeudColors.stage,
  onSurface: FeudColors.text,
  error: FeudColors.pink,
);

ThemeData _feudTheme() => ThemeData(
      brightness: Brightness.dark,
      colorScheme: _feudColorScheme,
      scaffoldBackgroundColor: FeudColors.canvas,
      fontFamily: bodyFontFamily,
      useMaterial3: true,
    );

/// التطبيق عربي فقط بهاد الإصدار، فمنثبّت اتجاه الواجهة RTL بدل ما نتكل
/// على لغة الجهاز.
Widget feudApp(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _feudTheme(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
    );
