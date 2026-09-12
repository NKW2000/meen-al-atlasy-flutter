/// `AppScope` — بيوصّل [HostController] و[PlayerController] و
/// [SettingsRepository] لكل شجرة الواجهة، بدل ما كل شاشة تركّب اعتماداتها
/// من الصفر (Task 6، حكم المتحكمات ٧).
///
/// التركيب الفعلي (بناء `HostServer`/`RoomBeacon`/`PlayerClient`/
/// `RoomDiscovery` الحقيقية، وتمرير `SettingsRepository.newGameState` كـ
/// `newGame` لـ[HostController]) بيصير بـ`main.dart` — لسا مش مكتوب (مهمة
/// لاحقة). السبب: `newGame` لازم تكون دالة **متزامنة** (`GameState
/// Function()`, نفس توقيع `HostViewModel.kt` الأصلي بالضبط، حكم ٣)، بينما
/// قراءة الإعدادات والبنك (`SettingsRepository.newGameState()`) غير
/// متزامنة بـDart (`SharedPreferences`/`dart:io` غير حاجبين هون، بعكس
/// Kotlin). فالتوصيل الحقيقي لازم يجهّز حالة اللعبة الجديدة مسبقاً (مثلاً
/// بشاشة "لعبة جديدة") وبعدين يمرّرها لدالة متزامنة بترجع آخر حالة
/// محضّرة — هاد قرار طبقة الواجهة (Task 7+)، مش هاد الملف.
library;

import 'package:flutter/widgets.dart';

import 'host_controller.dart';
import 'player_controller.dart';
import 'settings_repository.dart';

class AppScope extends InheritedWidget {
  final HostController host;
  final PlayerController player;
  final SettingsRepository settings;

  const AppScope({
    super.key,
    required this.host,
    required this.player,
    required this.settings,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      host != oldWidget.host ||
      player != oldWidget.player ||
      settings != oldWidget.settings;
}
