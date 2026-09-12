/// نقطة إقلاع التطبيق وخريطة التنقّل — نفس `MainActivity.kt` +
/// `FeudNavGraph.kt` بالمشروع الأصلي (Kotlin): شاشة كاملة بدون أشرطة
/// نظام (تحت النتش كمان)، بكل الاتجاهات الأربعة، وشبكة تنقّل بمسارات
/// مسمّاة وانتقال موحّد (سحبة + تلاشي).
///
/// وضع العرض (`DEMO=true` بوقت البناء) بيبلّش على معرض شاشات بدل
/// المقدمة — الشاشة نفسها مهمة لاحقة (Task 12)، هون بس مسار مؤقت.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/host_controller.dart';
import 'app/player_controller.dart';
import 'app/scope.dart';
import 'app/settings_repository.dart';
import 'game/settings.dart';
import 'network/host_server.dart';
import 'network/player_client.dart';
import 'network/room_beacon.dart';
import 'network/room_discovery.dart';
import 'ui/home/home_screen.dart';
import 'ui/host/host_settings_screen.dart';
import 'ui/intro/intro_screen.dart';
import 'ui/settings/bank_settings_screen.dart';
import 'ui/theme.dart';

/// وضع العرض — نفس فكرة `BuildConfig.DEBUG`/فليفر `demo` بالكوتلن، هون
/// عن طريق `--dart-define=DEMO=true` وقت البناء.
const bool demo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // لعبة على تلفزيون الصالون: بدون شريط حالة ولا شريط تنقّل — بيرجعوا
  // مؤقتاً بسحبة من الحافة وبيختفوا لحالهم (نفس `goFullScreen()` بكوتلن).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // الخلفية بتمتد تحت النتش، والمحتوى بينحط داخل المنطقة الآمنة (كل
  // شاشة بتحط SafeArea لحالها).
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  // كل الاتجاهات الأربعة — نفس `android:screenOrientation="fullUser"`.
  await SystemChrome.setPreferredOrientations(const []);

  runApp(await bootstrap());
}

/// بيبني شجرة الاعتماديات مرة وحدة عند الإقلاع — نفس ترتيب توثيق
/// [AppScope]: `warmUp()` لازم تنستنى قبل بناء [HostController].
Future<Widget> bootstrap() async {
  final prefs = await SharedPreferences.getInstance();
  final bankDir = await getApplicationSupportDirectory();
  final settings = SettingsRepository(prefs, bankDir);
  await settings.warmUp();

  final host = HostController(
    server: HostServer(),
    beacon: RoomBeacon(),
    newGame: settings.newGameStateSync,
    roomName: () => settings.roomName,
    freshQuestion: settings.freshQuestionSync,
    onQuestionShown: settings.markQuestionRead,
  );
  final player = PlayerController(discovery: RoomDiscovery(), client: PlayerClient());

  return AppScope(
    host: host,
    player: player,
    settings: settings,
    child: const FeudRoot(),
  );
}

class FeudRoot extends StatelessWidget {
  const FeudRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return feudApp(
      null,
      initialRoute: demo ? 'demo' : 'intro',
      onGenerateRoute: _onGenerateRoute,
    );
  }
}

/// نفس `NavHost` بـ`FeudNavGraph.kt`: انتقال سحبة ٣٤٠ملل + تلاشي ٢٤٠ملل
/// للأمام وللخلف، وكل شاشة جوّا `Scaffold` بخلفية بنفسجية غامقة بدون
/// أي حجز مساحة لأشرطة النظام.
Route<dynamic> _onGenerateRoute(RouteSettings routeSettings) {
  final Widget page;
  switch (routeSettings.name) {
    case 'intro':
      page = Builder(
        builder: (context) => IntroScreen(
          onDone: () => Navigator.of(context).pushReplacementNamed('home'),
        ),
      );

    case 'demo':
      // TODO(task 12): معرض الشاشات — هون بس مسار مؤقت حتى تشتغل شبكة
      // التنقّل وتنبني وضع العرض.
      page = _placeholder('demo');

    case 'home':
      page = Builder(
        builder: (context) {
          final scope = AppScope.of(context);
          return HomeScreen(
            onHostClick: () async {
              // لعبة جديدة: بدون لاعبين ولا نقاط من اللعبة اللي راحت.
              await scope.host.resetSession();
              if (context.mounted) Navigator.of(context).pushNamed('hostSettings');
            },
            onJoinClick: () => Navigator.of(context).pushNamed('playerJoin'),
            onSettingsClick: () => Navigator.of(context).pushNamed('bankSettings'),
          );
        },
      );

    case 'hostSettings':
      page = const _HostSettingsRoute();

    case 'bankSettings':
      page = Builder(
        builder: (context) => BankSettingsScreen(
          settings: AppScope.of(context).settings,
          onBack: () => Navigator.of(context).pop(),
        ),
      );

    // الشاشات الجاية بمهام لاحقة — مسار مؤقت حتى تشتغل شبكة التنقّل
    // وتنعمل تجربة دخان (smoke test) عليها.
    case 'hostLobby':
      page = _placeholder('hostLobby'); // TODO(task 9)
    case 'hostBoard':
      page = _placeholder('hostBoard'); // TODO(task 10)
    case 'hostResult':
      page = _placeholder('hostResult'); // TODO(task 10)
    case 'playerJoin':
      page = _placeholder('playerJoin'); // TODO(task 11)
    case 'playerRooms':
      page = _placeholder('playerRooms'); // TODO(task 11)
    case 'playerBuzzer':
      page = _placeholder('playerBuzzer'); // TODO(task 11)

    default:
      page = _placeholder(routeSettings.name ?? '?');
  }

  return _slideFadeRoute(page, settings: routeSettings);
}

Widget _placeholder(String routeName) => Scaffold(
      backgroundColor: FeudColors.deepNavy,
      body: Center(
        child: Text(routeName, style: const TextStyle(color: FeudColors.text)),
      ),
    );

/// جسم كل مسار بـ[Scaffold] بخلفية بنفسجية غامقة بدون حجز مساحة
/// لأشرطة النظام — نفس `Scaffold(containerColor = deepNavy,
/// contentWindowInsets = WindowInsets(0, 0, 0, 0))` بـ`FeudNavGraph.kt`.
PageRoute<dynamic> _slideFadeRoute(Widget page, {required RouteSettings settings}) {
  final body = Scaffold(backgroundColor: FeudColors.deepNavy, body: page);

  return PageRouteBuilder<dynamic>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (context, animation, secondaryAnimation) => body,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const fadeFraction = 240 / 340;
      final slideIn = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.fastOutSlowIn))
          .animate(animation);
      final fadeIn = Tween<double>(begin: 0, end: 1)
          .chain(CurveTween(curve: Interval(0, fadeFraction, curve: Curves.fastOutSlowIn)))
          .animate(animation);
      final slideOut = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.25, 0))
          .chain(CurveTween(curve: Curves.fastOutSlowIn))
          .animate(secondaryAnimation);
      final fadeOut = Tween<double>(begin: 1, end: 0)
          .chain(CurveTween(curve: Interval(0, fadeFraction, curve: Curves.fastOutSlowIn)))
          .animate(secondaryAnimation);

      return SlideTransition(
        position: slideOut,
        child: FadeTransition(
          opacity: fadeOut,
          child: SlideTransition(
            position: slideIn,
            child: FadeTransition(opacity: fadeIn, child: child),
          ),
        ),
      );
    },
  );
}

/// غلاف مسار إعدادات المضيف: بيحمّل حدود الأجوبة وعدد الأسئلة المطابقة
/// بشكل غير متزامن من [SettingsRepository] (`answerBounds`/`matchingCount`)
/// وبيحفظ كل تغيير فوراً — نفس `settingsViewModel` + `HostSettingsScreen`
/// composable بـ`FeudNavGraph.kt`، بس بدون صنف ViewModel منفصل.
class _HostSettingsRoute extends StatefulWidget {
  const _HostSettingsRoute();

  @override
  State<_HostSettingsRoute> createState() => _HostSettingsRouteState();
}

class _HostSettingsRouteState extends State<_HostSettingsRoute> {
  late final SettingsRepository _repo;
  late GameSettings _settings;
  (int, int) _bounds = (GameSettings.minAnswersBound, GameSettings.maxAnswersBound);
  int _matching = 0;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _repo = AppScope.of(context).settings;
    _settings = _repo.current;
    unawaited(_refreshDerived());
  }

  Future<void> _refreshDerived() async {
    final bounds = await _repo.answerBounds();
    final matching = await _repo.matchingCount(_settings);
    if (!mounted) return;
    setState(() {
      _bounds = bounds;
      _matching = matching;
    });
  }

  Future<void> _onSettingsChange(GameSettings next) async {
    setState(() => _settings = next);
    await _repo.save(next);
    if (!mounted) return;
    setState(() => _settings = _repo.current);
    await _refreshDerived();
  }

  @override
  Widget build(BuildContext context) {
    return HostSettingsScreen(
      settings: _settings,
      onSettingsChange: (next) => unawaited(_onSettingsChange(next)),
      onBack: () => Navigator.of(context).pop(),
      onContinue: () => Navigator.of(context).pushNamed('hostLobby'),
      answerBounds: _bounds,
      matchingQuestions: _matching,
    );
  }
}
