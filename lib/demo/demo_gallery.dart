/// معرض الشاشات — نسخة الديمو. بيعرض كل شاشة باللعبة بحالة مزيّفة، فبتقدر
/// تتفرّج عليهن وتعدّل بالتصميم بجهاز واحد، بدون مضيف ولا لاعبين ولا شبكة.
///
/// الشاشات شغّالة فعلياً (أزرارها بتضغط)، بس ما ورا أي زر منطق لعبة —
/// التنقّل بينهن من الشريط اللي تحت.
///
/// منفّذ عن `demo/DemoGallery.kt` بالمشروع الأصلي (Kotlin).
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../app/host_controller.dart';
import '../app/settings_repository.dart';
import '../game/models.dart';
import '../game/settings.dart';
import '../network/player_client.dart';
import '../network/room_discovery.dart';
import '../ui/components/stage.dart';
import '../ui/home/home_screen.dart';
import '../ui/host/host_board_screen.dart';
import '../ui/host/host_lobby_screen.dart';
import '../ui/host/host_settings_screen.dart';
import '../ui/intro/intro_screen.dart';
import '../ui/player/player_join_screen.dart';
import '../ui/player/player_screen.dart';
import '../ui/player/room_list_screen.dart';
import '../ui/settings/bank_settings_screen.dart';
import '../ui/show/game_over_screen.dart';
import '../ui/show/round_opening.dart';
import '../ui/show/scoreboard_screen.dart';
import '../ui/theme.dart';
import 'demo_data.dart';

class _DemoScreen {
  final String title;
  final WidgetBuilder content;

  const _DemoScreen(this.title, this.content);
}

class DemoGallery extends StatefulWidget {
  /// شاشة إعدادات البنك بدها مستودع حقيقي — بالديمو بيجي من `AppScope`
  /// (بدون استيراد فعلي، الأزرار بس بتنضغط).
  final SettingsRepository settingsRepository;

  const DemoGallery({super.key, required this.settingsRepository});

  @override
  State<DemoGallery> createState() => _DemoGalleryState();
}

class _DemoGalleryState extends State<DemoGallery> {
  int _index = 0;
  GameSettings _settings = const GameSettings();

  List<_DemoScreen> get _screens => _demoScreens(
        _settings,
        (next) => setState(() => _settings = next.clamped()),
        widget.settingsRepository,
      );

  @override
  Widget build(BuildContext context) {
    final screens = _screens;
    final index = _index.clamp(0, screens.length - 1);
    final current = screens[index];

    return Stack(
      fit: StackFit.expand,
      children: [
        // مفتاح لكل شاشة حتى تبلّش حركاتها من أولها لما ننقّل.
        KeyedSubtree(key: ValueKey(index), child: current.content(context)),

        // شريط التنقّل: بيطفو فوق الشاشة، وبيضل صغير حتى ما يغطّيها.
        Positioned(
          left: 0,
          right: 0,
          bottom: 6,
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NavKey(
                  label: '‹',
                  onClick: () => setState(() => _index = (index + screens.length - 1) % screens.length),
                ),
                const SizedBox(width: 8),
                CartoonSurface(
                  color: FeudColors.ink.withValues(alpha: 0.92),
                  borderWidth: 2,
                  corner: 10,
                  shadow: 3,
                  child: SizedBox(
                    width: 230,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(
                        '${index + 1}/${screens.length} · ${current.title}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FeudText.labelLarge(context).copyWith(color: FeudColors.gold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _NavKey(
                  label: '›',
                  onClick: () => setState(() => _index = (index + 1) % screens.length),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NavKey extends StatelessWidget {
  final String label;
  final VoidCallback onClick;

  const _NavKey({required this.label, required this.onClick});

  @override
  Widget build(BuildContext context) {
    return CartoonSurface(
      color: FeudColors.gold,
      borderWidth: 2,
      corner: 10,
      shadow: 3,
      onClick: onClick,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Center(
          child: Text(label, style: FeudText.titleLarge(context).copyWith(color: FeudColors.ink)),
        ),
      ),
    );
  }
}

List<_DemoScreen> _demoScreens(
  GameSettings settings,
  void Function(GameSettings) onSettings,
  SettingsRepository repository,
) {
  final rooms = [
    Room('غرفة العيلة', InternetAddress('192.168.1.5'), 47215),
    Room('سهرة الجمعة', InternetAddress('192.168.1.9'), 47215),
    Room('غرفة الشباب', InternetAddress('192.168.1.12'), 47215),
  ];

  return [
    _DemoScreen('المقدمة', (_) => IntroScreen(onDone: () {})),
    _DemoScreen(
      'الرئيسية',
      (_) => HomeScreen(onHostClick: () {}, onJoinClick: () {}, onSettingsClick: () {}),
    ),
    _DemoScreen(
      'الإعدادات العامة',
      (_) => BankSettingsScreen(settings: repository, onBack: () {}),
    ),
    _DemoScreen(
      'إعدادات المضيف',
      (_) => HostSettingsScreen(
        settings: settings,
        onSettingsChange: onSettings,
        onBack: () {},
        onContinue: () {},
        matchingQuestions: 32,
      ),
    ),
    _DemoScreen(
      'لوبي المضيف',
      (_) => HostLobbyScreen(
        roomName: 'غرفة العيلة',
        teams: demoState().teams,
        players: demoPlayers,
        advertising: true,
        minPerTeam: HostController.minPlayersPerTeam,
        ip: InternetAddress('192.168.43.1'),
        onStartHosting: () {},
        onMovePlayer: (_, _) {},
        onBeginGame: () {},
      ),
    ),
    _DemoScreen(
      'لوح المضيف — مواجهة',
      (_) => HostGameBoardScreen(
        state: demoState(phase: RoundPhase.faceOff, revealed: 0, strikes: 0),
        onCorrect: (_) {},
        onWrong: () {},
        onNextRound: () {},
        onChangeQuestion: () {},
      ),
    ),
    _DemoScreen(
      'لوح المضيف — لعب',
      (_) => HostGameBoardScreen(
        state: demoState(),
        onCorrect: (_) {},
        onWrong: () {},
        onNextRound: () {},
      ),
    ),
    _DemoScreen(
      'لوح المضيف — نهاية الجولة',
      (_) => HostGameBoardScreen(
        state: demoState(phase: RoundPhase.roundEnd, revealed: 6),
        onCorrect: (_) {},
        onWrong: () {},
        onNextRound: () {},
      ),
    ),
    _DemoScreen('بداية الجولة', (_) => const RoundIntroScreen(round: 3, multiplier: 2)),
    _DemoScreen(
      'استعدوا',
      (_) => const VersusScreen(
        playerA: 'سامر',
        playerB: 'ليلى',
        teamAName: 'نمور الشام',
        teamBName: 'صقور البحر',
      ),
    ),
    _DemoScreen(
      'النتيجة بين الجولات',
      (_) => ScoreboardScreen(
        state: demoState(phase: RoundPhase.scoreboard, revealed: 6),
        onContinue: () {},
      ),
    ),
    _DemoScreen(
      'نهاية اللعبة',
      (_) => GameOverScreen(
        state: demoState(phase: RoundPhase.gameOver, revealed: 6, gameOver: true),
        onBackHome: () {},
        onBackToLobby: () {},
      ),
    ),
    _DemoScreen('انضمام لاعب', (_) => PlayerJoinScreen(onJoinConfirmed: (_) {})),
    _DemoScreen(
      'لستة الغرف',
      (_) => RoomListScreen(
        playerName: 'عبد الرحمن',
        rooms: rooms,
        onPick: (_) {},
        onEnterCode: (_) {},
        onBack: () {},
      ),
    ),
    _DemoScreen(
      'لوبي اللاعب',
      (_) => PlayerScreen(
        state: demoState(matchStarted: false, revealed: 0),
        playerId: 'a1',
        teamId: TeamId.team1,
        mark: PlayerMark.idle,
        status: ConnectionStatus.connected,
        onBuzz: () {},
      ),
    ),
    _DemoScreen(
      'زر اللاعب',
      (_) => PlayerScreen(
        state: demoState(phase: RoundPhase.faceOff, revealed: 0, strikes: 0, maskQuestion: true),
        playerId: 'a1',
        teamId: TeamId.team1,
        mark: PlayerMark.armed,
        status: ConnectionStatus.connected,
        onBuzz: () {},
      ),
    ),
    _DemoScreen(
      'لوح اللاعب',
      (_) => PlayerScreen(
        state: demoState(maskQuestion: true),
        playerId: 'a2',
        teamId: TeamId.team1,
        mark: PlayerMark.armed,
        status: ConnectionStatus.connected,
        onBuzz: () {},
      ),
    ),
    _DemoScreen(
      'اللاعب — غلط',
      (_) => PlayerScreen(
        state: demoState(maskQuestion: true, strikes: 3),
        playerId: 'a2',
        teamId: TeamId.team1,
        mark: PlayerMark.wrong,
        status: ConnectionStatus.connected,
        onBuzz: () {},
      ),
    ),
    _DemoScreen(
      'يلعب أو يمرّر',
      (_) => PlayerScreen(
        state: demoState(phase: RoundPhase.playOrPass, revealed: 1, maskQuestion: true),
        playerId: 'a1',
        teamId: TeamId.team1,
        mark: PlayerMark.armed,
        status: ConnectionStatus.connected,
        onBuzz: () {},
        onChoose: (_) {},
      ),
    ),
  ];
}
