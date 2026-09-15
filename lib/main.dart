/// نقطة إقلاع التطبيق وخريطة التنقّل — نفس `MainActivity.kt` +
/// `FeudNavGraph.kt` بالمشروع الأصلي (Kotlin): شاشة كاملة بدون أشرطة
/// نظام (تحت النتش كمان)، بكل الاتجاهات الأربعة، وشبكة تنقّل بمسارات
/// مسمّاة وانتقال موحّد (سحبة + تلاشي).
///
/// وضع العرض (`DEMO=true` بوقت البناء) بيبلّش على معرض شاشات بدل
/// المقدمة.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/host_controller.dart';
import 'app/player_controller.dart';
import 'app/scope.dart';
import 'app/settings_repository.dart';
import 'demo/demo_gallery.dart';
import 'feedback/game_cues.dart';
import 'feedback/game_feedback.dart';
import 'game/models.dart';
import 'game/settings.dart';
import 'network/host_server.dart';
import 'network/local_ip.dart';
import 'network/player_client.dart';
import 'network/room_beacon.dart';
import 'network/room_discovery.dart';
import 'ui/components/confirm_dialog.dart';
import 'ui/components/error_snackbar.dart';
import 'ui/home/home_screen.dart';
import 'ui/host/host_board_screen.dart';
import 'ui/host/host_lobby_screen.dart';
import 'ui/host/host_settings_screen.dart';
import 'ui/intro/intro_screen.dart';
import 'ui/player/player_join_screen.dart';
import 'ui/player/player_screen.dart';
import 'ui/player/room_list_screen.dart';
import 'ui/settings/about_screen.dart';
import 'ui/settings/bank_settings_screen.dart';
import 'ui/show/game_over_screen.dart';
import 'ui/show/round_opening.dart';
import 'ui/show/scoreboard_screen.dart';
import 'ui/theme.dart';

/// وضع العرض — نفس فكرة `BuildConfig.DEBUG`/فليفر `demo` بالكوتلن، هون
/// عن طريق `--dart-define=DEMO=true` وقت البناء.
const bool demo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // أي ويدجت بينفجر ببنائه بوضع الإصدار بينرسم افتراضياً كمستطيل رمادي
  // بحجم غير محدود بيدفش كل اللي حوله برّا الشاشة وما بيقول شي. بدله:
  // بلوك وردي صغير فيه نص الخطأ — بينقرا وبينصوّر وبينبعت.
  ErrorWidget.builder = (details) => Material(
    color: FeudColors.pink,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        'خطأ بالعرض: ${details.exception}',
        style: const TextStyle(color: FeudColors.cream, fontSize: 12),
      ),
    ),
  );

  // لعبة على تلفزيون الصالون: بدون شريط حالة ولا شريط تنقّل — بيرجعوا
  // مؤقتاً بسحبة من الحافة وبيختفوا لحالهم (نفس `goFullScreen()` بكوتلن).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // الخلفية بتمتد تحت النتش، والمحتوى بينحط داخل المنطقة الآمنة (كل
  // شاشة بتحط SafeArea لحالها).
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  // كل الاتجاهات الأربعة — نفس `android:screenOrientation="fullUser"`.
  await SystemChrome.setPreferredOrientations(const []);
  // شاشات ٩٠/١٢٠ هرتز: أندرويد بيشغّل التطبيق على ٦٠ افتراضياً، فالحركات
  // (كشف الخانة، الأبواب، العدّاد) بتبيّن أخشن من الجهاز نفسه. منطلب أعلى
  // تردّد متاح — وبيتجاهل بصمت على أجهزة/أنظمة ما بتدعمه.
  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {}
  }

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
    // نسخة وحدة من الصوت/الاهتزاز للتطبيق كله — `ProvideGameFeedback`.
    child: GameFeedbackScope(feedback: GameFeedback(), child: const FeudRoot()),
  );
}

class FeudRoot extends StatelessWidget {
  const FeudRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return feudApp(null, initialRoute: demo ? 'demo' : 'intro', onGenerateRoute: _onGenerateRoute);
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
        builder: (context) =>
            IntroScreen(onDone: () => Navigator.of(context).pushReplacementNamed('home')),
      );

    case 'demo':
      // معرض الشاشات — نسخة الديمو بتبلّش هون بدل المقدمة.
      page = Builder(
        builder: (context) => DemoGallery(settingsRepository: AppScope.of(context).settings),
      );

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
          onAbout: () => Navigator.of(context).pushNamed('about'),
        ),
      );

    case 'about':
      page = Builder(
        builder: (context) => AboutScreen(onBack: () => Navigator.of(context).pop()),
      );

    case 'hostLobby':
      page = const _HostLobbyRoute();

    case 'playerJoin':
      page = Builder(
        builder: (context) => PlayerJoinScreen(
          onJoinConfirmed: (name) {
            // الاسم أول، وبعدين بيختار الغرفة من اللستة.
            AppScope.of(context).player.join(name);
            Navigator.of(context).pushNamed('playerRooms');
          },
        ),
      );

    case 'playerRooms':
      page = const _PlayerRoomsRoute();

    case 'playerBuzzer':
      page = const _PlayerBuzzerRoute();

    case 'hostBoard':
      page = const _HostBoardRoute();

    case 'hostResult':
      page = Builder(
        builder: (context) {
          final host = AppScope.of(context).host;
          return ListenableBuilder(
            listenable: host,
            builder: (context, _) => GameOverScreen(
              state: host.state,
              onBackHome: () {
                // خلصت اللعبة: منسكّر الغرفة حتى ما يضل اللاعبين معلّقين عليها.
                unawaited(host.resetSession());
                Navigator.of(context).popUntil((route) => route.settings.name == 'home');
              },
              onBackToLobby: () {
                // نفس الغرفة ونفس اللاعبين — بس نقاط وأسئلة جديدة،
                // واللاعبين بيرجعوا يختاروا فرقهم من اللوبي.
                unawaited(host.backToLobby());
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('hostLobby', (route) => route.settings.name == 'home');
              },
            ),
          );
        },
      );

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
      final slideIn = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.fastOutSlowIn)).animate(animation);
      final fadeIn = Tween<double>(begin: 0, end: 1)
          .chain(CurveTween(curve: Interval(0, fadeFraction, curve: Curves.fastOutSlowIn)))
          .animate(animation);
      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.25, 0),
      ).chain(CurveTween(curve: Curves.fastOutSlowIn)).animate(secondaryAnimation);
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

/// غلاف مسار لوبي المضيف: بيسمع [HostController]، وبيقرأ عنوان الواي
/// فاي كل شوي (المضيف ممكن يشغّل الواي فاي أو نقطة الاتصال وهو عالشاشة)
/// حتى يبيّن العنوان — نفس `HOST_SETUP` بـ`FeudNavGraph.kt`،
/// زائد الإضافة الوحيدة بالمواصفة (§3).
class _HostLobbyRoute extends StatefulWidget {
  const _HostLobbyRoute();

  @override
  State<_HostLobbyRoute> createState() => _HostLobbyRouteState();
}

class _HostLobbyRouteState extends State<_HostLobbyRoute> {
  InternetAddress? _ip;
  Timer? _ipTimer;
  bool _applied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_applied) return;
    _applied = true;
    // أسماء الفرق والجولات والوقت من شاشة الإعدادات — اللوبي بيبني الحالة
    // منها هلق، مش من لحظة الضغط على «استضافة».
    AppScope.of(context).host.applySettings();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_refreshIp());
    _ipTimer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(_refreshIp()));
  }

  Future<void> _refreshIp() async {
    final ip = await wifiIPv4();
    if (!mounted || ip?.address == _ip?.address) return;
    setState(() => _ip = ip);
  }

  @override
  void dispose() {
    _ipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final host = scope.host;
    return ListenableBuilder(
      listenable: host,
      builder: (context, _) => ErrorSnackbar(
        message: host.lastError,
        onShown: host.dismissError,
        child: HostLobbyScreen(
          roomName: scope.settings.roomName,
          teams: host.state.teams,
          players: host.state.players,
          advertising: host.advertising,
          minPerTeam: HostController.minPlayersPerTeam,
          ip: _ip,
          onStartHosting: () => unawaited(host.startHosting()),
          onMovePlayer: host.movePlayer,
          onBeginGame: () {
            if (!host.canStart) return;
            host.startGame();
            Navigator.of(context).pushNamed('hostBoard');
          },
        ),
      ),
    );
  }
}

/// غلاف مسار لستة الغرف: أول ما نتصل بغرفة، بنفوت على شاشة اللعب —
/// نفس `PLAYER_ROOMS` بـ`FeudNavGraph.kt`. الرجوع بيوقّف البحث.
class _PlayerRoomsRoute extends StatefulWidget {
  const _PlayerRoomsRoute();

  @override
  State<_PlayerRoomsRoute> createState() => _PlayerRoomsRouteState();
}

class _PlayerRoomsRouteState extends State<_PlayerRoomsRoute> {
  PlayerController? _player;
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = AppScope.of(context).player;
    if (identical(player, _player)) return;
    _player?.removeListener(_onPlayerChanged);
    _player = player..addListener(_onPlayerChanged);
    _onPlayerChanged();
  }

  void _onPlayerChanged() {
    if (_navigated || _player!.status != ConnectionStatus.connected) return;
    _navigated = true;
    // بعد الإطار الحالي — `notifyListeners` ممكن يجي من جوّا build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pushReplacementNamed('playerBuzzer');
    });
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => ErrorSnackbar(
        message: player.lastError,
        onShown: player.dismissError,
        child: RoomListScreen(
          playerName: player.pendingName ?? '',
          rooms: player.rooms,
          onPick: (room) => unawaited(player.enterRoom(room)),
          onBack: () {
            unawaited(player.stopDiscovery());
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

/// غلاف مسار جهاز اللاعب — نفس `PLAYER_BUZZER` بـ`FeudNavGraph.kt`:
/// اللوبي قبل ما تبلّش اللعبة، وحوار «انقطعت/تطلع؟» بالرجوع أو لما
/// ينقطع الاتصال، بخيارين: ارجع لنفس اللعبة (`rejoin`) أو اطلع عالرئيسية.
/// شاشات اللعب نفسها (الزر واللوح) مهمة لاحقة (Task 10).
class _PlayerBuzzerRoute extends StatefulWidget {
  const _PlayerBuzzerRoute();

  @override
  State<_PlayerBuzzerRoute> createState() => _PlayerBuzzerRouteState();
}

class _PlayerBuzzerRouteState extends State<_PlayerBuzzerRoute> {
  PlayerController? _player;
  bool _showLeft = false;
  ConnectionStatus? _lastStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = AppScope.of(context).player;
    if (identical(player, _player)) return;
    _player?.removeListener(_onPlayerChanged);
    _player = player..addListener(_onPlayerChanged);
    _lastStatus = player.status;
  }

  /// `LaunchedEffect(status) { if (DISCONNECTED) showLeft = true }`.
  void _onPlayerChanged() {
    final status = _player!.status;
    if (status == _lastStatus) return;
    _lastStatus = status;
    if (status == ConnectionStatus.disconnected && !_showLeft) {
      setState(() => _showLeft = true);
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_showLeft) setState(() => _showLeft = true);
      },
      child: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final live = player.state;

          final mark = player.mark();
          final Widget body;
          if (live != null && live.gameOver) {
            body = GameOverScreen(state: live);
          } else if (live != null && live.phase == RoundPhase.scoreboard) {
            body = ScoreboardScreen(state: live);
          } else {
            body = PlayerScreen(
              state: live,
              playerId: player.playerId,
              teamId: player.teamId,
              mark: mark,
              status: player.status,
              onBuzz: player.onBuzzTapped,
              onChoose: player.choose,
              onChangeTeam: player.changeTeam,
            );
          }

          // الصوت والاهتزاز: أحداث اللعبة ودقّات آخر خمس ثواني (صوت الضغطة
          // بيطلع من الزر/اللوح نفسه لحظة الضغط، مش من الحالة الراجعة).
          return GameCues(
            state: live,
            child: CountdownCues(
              seconds: live == null ? 0 : math.max(live.answerSecondsLeft, live.choiceSecondsLeft),
              child: ErrorSnackbar(
                message: player.lastError,
                onShown: player.dismissError,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    body,
                    // نفس افتتاحية الجولة اللي عند المضيف — بتطلع فوق الزر.
                    RoundOpeningOverlay(state: live),
                    if (_showLeft)
                      ConfirmDialog(
                        title: player.status == ConnectionStatus.disconnected
                            ? 'انقطعت عن اللعبة'
                            : 'تطلع من اللعبة؟',
                        message: 'بتقدر ترجع لنفس اللعبة، أو تطلع وتبلّش من جديد.',
                        confirmText: 'ارجع لللعبة',
                        dismissText: 'اطلع وابدأ من جديد',
                        confirmColor: FeudColors.lime,
                        onConfirm: () {
                          setState(() => _showLeft = false);
                          unawaited(player.rejoin());
                        },
                        onDismiss: () {
                          setState(() => _showLeft = false);
                          // طلوع نهائي: بدون اتصال ولا حالة قديمة للانضمام الجاي.
                          unawaited(player.leave());
                          Navigator.of(context).popUntil((route) => route.settings.name == 'home');
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// غلاف مسار لوح المضيف — نفس `HOST_BOARD` بـ`FeudNavGraph.kt`: اللوح
/// (أو لوحة النتيجة بين الجولات)، افتتاحية كل جولة فوقه، حوار «تطلع من
/// اللعبة؟» بالرجوع، والانتقال لشاشة النتيجة النهائية لما تخلص اللعبة.
class _HostBoardRoute extends StatefulWidget {
  const _HostBoardRoute();

  @override
  State<_HostBoardRoute> createState() => _HostBoardRouteState();
}

class _HostBoardRouteState extends State<_HostBoardRoute> {
  HostController? _host;
  bool _confirmExit = false;
  bool _navigatedToResult = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = AppScope.of(context).host;
    if (identical(host, _host)) return;
    _host?.removeListener(_onHostChanged);
    _host = host..addListener(_onHostChanged);
    _onHostChanged();
  }

  /// `LaunchedEffect(state.gameOver)` — للنتيجة النهائية مرة وحدة.
  void _onHostChanged() {
    if (_navigatedToResult || !_host!.state.gameOver) return;
    _navigatedToResult = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pushReplacementNamed('hostResult');
    });
  }

  @override
  void dispose() {
    _host?.removeListener(_onHostChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = AppScope.of(context).host;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_confirmExit) setState(() => _confirmExit = true);
      },
      child: ListenableBuilder(
        listenable: host,
        builder: (context, _) {
          final state = host.state;
          final Widget body = state.phase == RoundPhase.scoreboard
              ? ScoreboardScreen(state: state, onContinue: host.nextRound)
              : HostGameBoardScreen(
                  state: state,
                  onCorrect: host.judgeCorrect,
                  onWrong: host.judgeWrong,
                  onNextRound: host.nextRound,
                  onChangeQuestion: host.changeQuestion,
                );

          // الصوت والاهتزاز عند المضيف: أحداث اللعبة ودقّات آخر خمس ثواني.
          return GameCues(
            state: state,
            child: CountdownCues(
              seconds: math.max(state.answerSecondsLeft, state.choiceSecondsLeft),
              child: ErrorSnackbar(
                message: host.lastError,
                onShown: host.dismissError,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    body,
                    // افتتاحية كل جولة: اسم الجولة والمضاعف، وبعدها «استعدوا»
                    // بأسماء اللي عالمنصة — نفسها عند اللاعبين.
                    RoundOpeningOverlay(state: state),
                    if (_confirmExit)
                      ConfirmDialog(
                        title: 'تطلع من اللعبة؟',
                        message: 'اللعبة شغّالة — إذا طلعت بتنتهي عند كل اللاعبين.',
                        confirmText: 'اطلع',
                        dismissText: 'كمّل اللعب',
                        onConfirm: () {
                          setState(() => _confirmExit = false);
                          // «إذا طلعت بتنتهي عند كل اللاعبين» — فعلاً: منوقّف الخادم.
                          unawaited(host.resetSession());
                          Navigator.of(context).popUntil((route) => route.settings.name == 'home');
                        },
                        onDismiss: () => setState(() => _confirmExit = false),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
