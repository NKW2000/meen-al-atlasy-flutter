/// مولّد أيقونات — مش اختبار سلوك. بيرسم شارة التطبيق (نفس الأيقونة
/// التكيّفية بالأندرويد) لملفات PNG بالمقاسات اللي بتطلبها المنصّات:
/// أيقونات الأندرويد القديمة (mipmap-*)، أيقونات iOS، وfavicon الويب —
/// بدل شعار فلاتر الافتراضي اللي كان بمكانها.
///
/// بيشتغل بس لما تطلبه:
///   flutter test test/tools/render_icons_test.dart --dart-define=RENDER_ICONS=true
@Tags(['tools'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/ui/components/brand_logo.dart';
import 'package:meen_al_atlasy/ui/theme.dart';

const bool _enabled = bool.fromEnvironment('RENDER_ICONS');

/// المقاسات: مسار ← بكسل.
const Map<String, int> _targets = {
  'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
  'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  'web/favicon.png': 64,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png': 1024,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png': 167,
};

/// الأيقونة: خلفية بنفسجية (نفس ic_launcher_background) والشارة الذهبية
/// بالنص — بحجم ٧٦٪ من المربّع، متل الأيقونة التكيّفية.
Widget _icon(double px) => Container(
      width: px,
      height: px,
      color: const Color(0xFF2A1258),
      alignment: Alignment.center,
      child: BrandBadge(em: px * 0.76),
    );

void main() {
  testWidgets('render the app icon to every platform PNG', (tester) async {
    if (!_enabled) return;
    await loadGameFonts();
    for (final entry in _targets.entries) {
      final px = entry.value.toDouble();
      tester.view.physicalSize = Size(px, px);
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await tester.pumpWidget(feudApp(RepaintBoundary(key: key, child: _icon(px))));
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(entry.key).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    tester.view.reset();
  });
}

/// اختبارات فلاتر بترسم بخط Ahem — منحمّل خطوط اللعبة حتى تطلع «؟» صح.
Future<void> loadGameFonts() async {
  const fonts = {
    'BalooBhaijaan2': ['baloo_bhaijaan2_medium.ttf', 'baloo_bhaijaan2_bold.ttf', 'baloo_bhaijaan2_extrabold.ttf'],
    'Tajawal': ['tajawal_medium.ttf', 'tajawal_bold.ttf', 'tajawal_extrabold.ttf'],
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}
