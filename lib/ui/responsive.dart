/// التطبيق بيشتغل بالوضعين: الجهاز الأفقي (شاشة الغرفة الكبيرة) والجهاز
/// الطولي (موبايل بالإيد). كل شاشة بتبني نفس المحتوى بترتيبين:
///
/// - **أفقي**: أعمدة جنب بعض، وكل إشي داخل الشاشة بدون تمرير.
/// - **طولي**: عمود واحد بيتمرّر، والأزرار الأساسية ملزوقة تحت بمتناول
///   الإصبع.
///
/// القياسات النسبية (خط كبير، دوائر، لوحات) بتتحسب من [shortSide] — أقصر
/// بُعد بالشاشة — حتى ما تنفجر بالوضع الطولي.
///
/// منفّذ عن `Responsive.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/widgets.dart';

bool isPortrait(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.height > size.width;
}

/// أقصر بُعد بالشاشة بالمنطق (logical pixels).
double shortSide(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width < size.height ? size.width : size.height;
}

/// حشوة الشاشة — أوسع بالأفقي وأضيق بالطولي.
EdgeInsets stagePadding(BuildContext context) => isPortrait(context)
    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
    : const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
