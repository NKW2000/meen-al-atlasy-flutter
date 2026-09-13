/// `AppScope` — بيوصّل [HostController] و[PlayerController] و
/// [SettingsRepository] لكل شجرة الواجهة، بدل ما كل شاشة تركّب اعتماداتها
/// من الصفر (Task 6، حكم المتحكمات ٧).
///
/// التركيب الفعلي (`main.dart`، لسا مش مكتوب — مهمة لاحقة) بيصير هيك،
/// بالترتيب (قرار مراجعة الخيار ب — حلّ فجوة التزامن بين `newGame`
/// المتزامنة و`SettingsRepository` غير المتزامنة):
///
/// ```dart
/// final settings = SettingsRepository(await SharedPreferences.getInstance(), bankDir);
/// await settings.warmUp(); // يعبّي اللقطة المتزامنة قبل أي استعمال إلها
/// final host = HostController(
///   server: HostServer(),
///   beacon: RoomBeacon(),
///   newGame: settings.newGameStateSync,
///   roomName: () => settings.roomName,
///   freshQuestion: settings.freshQuestionSync,
///   onQuestionShown: settings.markQuestionRead,
/// );
/// ```
///
/// `settings.warmUp()` لازم تنستنى **قبل** بناء [HostController]، وكل
/// دالة كتابة بـ[SettingsRepository] (`save`/`importBank`/`clearBank`/…)
/// بتحدّث اللقطة المتزامنة بنفسها من بعدها — فما لازم تعيد نداء `warmUp`
/// يدوياً بعد كل تغيير إعدادات.
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
