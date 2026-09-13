/// اختبارات شاشات Task 9: لوبي المضيف (عنوان الواي فاي، بوابة الحد
/// الأدنى، نقل اللاعبين)، شاشة اسم اللاعب، لستة الغرف (اختيار غرفة أو
/// كتابة كود)، ولوبي اللاعب (فريقك + تبديل الفريق).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/network/room_discovery.dart';
import 'package:meen_al_atlasy/ui/host/host_lobby_screen.dart';
import 'package:meen_al_atlasy/ui/player/player_join_screen.dart';
import 'package:meen_al_atlasy/ui/player/player_lobby.dart';
import 'package:meen_al_atlasy/ui/player/room_list_screen.dart';
import 'package:meen_al_atlasy/ui/theme.dart';

import '../game/fixtures.dart';

const _teams = {
  TeamId.team1: TeamState(id: TeamId.team1, name: 'الفريق الأخضر', connected: true),
  TeamId.team2: TeamState(id: TeamId.team2, name: 'الفريق الأزرق', connected: true),
};

const _players = [
  Player(id: 'a1', name: 'سامر', teamId: TeamId.team1, seat: 1),
  Player(id: 'a2', name: 'هناء', teamId: TeamId.team1, seat: 2),
  Player(id: 'b1', name: 'ليلى', teamId: TeamId.team2, seat: 1),
];

/// الشاشات مبنية لتلفزيون/موبايل — منثبّت مقاس شاشة أفقية واسعة حتى ما
/// يطلع overflow بالاختبار ونفحص نفس التخطيط اللي بيشوفه المضيف.
Future<void> _pumpLandscape(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1600, 800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(feudApp(screen));
  await tester.pump();
}

Future<void> _pumpPortrait(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(feudApp(screen));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HostLobbyScreen', () {
    testWidgets('shows the Wi-Fi address and no room code', (tester) async {
      await _pumpLandscape(
        tester,
        HostLobbyScreen(
          roomName: 'غرفة العيلة',
          teams: _teams,
          players: _players,
          advertising: true,
          minPerTeam: 1,
          ip: InternetAddress('192.168.43.1'),
          onStartHosting: () {},
          onBeginGame: () {},
        ),
      );

      expect(find.text('غرفة العيلة'), findsOneWidget);
      expect(find.text('الواي فاي: 192.168.43.1'), findsOneWidget);
      expect(find.textContaining('كود الغرفة'), findsNothing);
      expect(find.text('لازم الكل يكون على نفس الواي فاي أو نقطة اتصال المضيف'), findsOneWidget);
      expect(find.text('جاهزين — يلا نبلّش'), findsOneWidget);
    });

    testWidgets('without Wi-Fi it asks to turn it on and blocks hosting', (tester) async {
      var hosting = false;
      await _pumpLandscape(
        tester,
        HostLobbyScreen(
          roomName: 'غرفة العيلة',
          teams: _teams,
          players: const [],
          advertising: false,
          minPerTeam: 1,
          ip: null,
          onStartHosting: () => hosting = true,
          onBeginGame: () {},
        ),
      );

      expect(find.text('افتح الواي فاي أو نقطة الاتصال'), findsOneWidget);
      expect(find.textContaining('الواي فاي:'), findsNothing);
      await tester.tap(find.text('بدء البث'));
      await tester.pump();
      expect(hosting, isFalse);
    });

    testWidgets('the start button waits for a player on each team', (tester) async {
      var started = false;
      await _pumpLandscape(
        tester,
        HostLobbyScreen(
          roomName: 'غرفة العيلة',
          teams: _teams,
          players: const [Player(id: 'a1', name: 'سامر', teamId: TeamId.team1, seat: 1)],
          advertising: true,
          minPerTeam: 1,
          ip: InternetAddress('192.168.43.1'),
          onStartHosting: () {},
          onBeginGame: () => started = true,
        ),
      );

      expect(find.text('بدنا لاعب بكل فريق عالأقل'), findsOneWidget);
      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pump();
      expect(started, isFalse);
    });

    testWidgets('the move button sends the player to the other team', (tester) async {
      final moves = <(String, TeamId)>[];
      await _pumpLandscape(
        tester,
        HostLobbyScreen(
          roomName: 'غرفة العيلة',
          teams: _teams,
          players: _players,
          advertising: true,
          minPerTeam: 1,
          ip: InternetAddress('192.168.43.1'),
          onStartHosting: () {},
          onBeginGame: () {},
          onMovePlayer: (id, team) => moves.add((id, team)),
        ),
      );

      // ليلى بالفريق التاني — زر التبديل تبعها هو التالت بالترتيب.
      await tester.tap(find.text('بدّل ⇄').at(2));
      await tester.pump();
      expect(moves, [('b1', TeamId.team1)]);
    });

    testWidgets('portrait stacks the teams and still fits the buttons', (tester) async {
      var started = false;
      await _pumpPortrait(
        tester,
        HostLobbyScreen(
          roomName: 'غرفة العيلة',
          teams: _teams,
          players: _players,
          advertising: true,
          minPerTeam: 1,
          ip: InternetAddress('192.168.43.1'),
          onStartHosting: () {},
          onBeginGame: () => started = true,
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pump();
      expect(started, isTrue);
    });
  });

  group('PlayerJoinScreen', () {
    testWidgets('the join button appears once a name is typed and sends it trimmed', (
      tester,
    ) async {
      String? joined;
      await _pumpPortrait(tester, PlayerJoinScreen(onJoinConfirmed: (n) => joined = n));

      expect(find.text('شو اسمك؟'), findsOneWidget);
      expect(find.text('يلا نلعب'), findsNothing);

      await tester.enterText(find.byType(TextField), 'عبد الرحمن ');
      await tester.pump();
      expect(find.text('يلا نلعب'), findsOneWidget);

      await tester.tap(find.text('يلا نلعب'));
      await tester.pump();
      expect(joined, 'عبد الرحمن');
    });

    testWidgets('the name is capped at 14 characters', (tester) async {
      await _pumpPortrait(tester, PlayerJoinScreen(onJoinConfirmed: (_) {}));

      await tester.enterText(find.byType(TextField), 'أبجدهوزحطيكلمنسع');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, 14);
    });
  });

  group('RoomListScreen', () {
    final rooms = [
      Room('غرفة العيلة', InternetAddress('192.168.1.5'), 47215),
      Room('غرفة الشباب', InternetAddress('192.168.1.9'), 47215),
    ];

    testWidgets('lists the rooms and picks one on tap', (tester) async {
      Room? picked;
      await _pumpLandscape(
        tester,
        RoomListScreen(
          playerName: 'عبد الرحمن',
          rooms: rooms,
          onPick: (r) => picked = r,
          onBack: () {},
        ),
      );

      expect(find.text('غرفة العيلة'), findsOneWidget);
      expect(find.text('غرفة الشباب'), findsOneWidget);
      expect(find.text('٢ غرفة قريبة'), findsOneWidget);

      await tester.tap(find.text('غرفة الشباب'));
      await tester.pump();
      expect(picked, rooms[1]);
    });

    testWidgets('shows the searching state when no rooms are around', (tester) async {
      await _pumpPortrait(
        tester,
        RoomListScreen(
          playerName: 'عبد الرحمن',
          rooms: const [],
          onPick: (_) {},
          onBack: () {},
        ),
      );

      expect(find.text('عم ندوّر على غرف قريبة'), findsOneWidget);
      expect(find.text('لازم الكل يكون على نفس الواي فاي أو نقطة اتصال المضيف'), findsOneWidget);
    });
  });

  group('PlayerLobbyScreen', () {
    testWidgets('marks my team and switches on tapping the other one', (tester) async {
      TeamId? changed;
      final state = freshState(players: _players);
      await _pumpLandscape(
        tester,
        PlayerLobbyScreen(
          state: state,
          playerId: 'a2',
          teamId: TeamId.team1,
          onChangeTeam: (t) => changed = t,
        ),
      );

      // اسمي بيطلع مرتين: بالرأس وبلستة فريقي.
      expect(find.text('هناء'), findsNWidgets(2));
      expect(find.text('فريقك'), findsOneWidget);
      expect(find.text('بانتظار المضيف يبلّش'), findsOneWidget);

      await tester.tap(find.text(state.teams[TeamId.team2]!.name));
      await tester.pump();
      expect(changed, TeamId.team2);

      // الدوس على فريقي ما بيبعت إشي.
      changed = null;
      await tester.tap(find.text(state.teams[TeamId.team1]!.name));
      await tester.pump();
      expect(changed, isNull);
    });

    testWidgets('portrait lays the rosters in two columns without overflow', (tester) async {
      await _pumpPortrait(
        tester,
        PlayerLobbyScreen(
          state: freshState(players: _players),
          playerId: 'b1',
          teamId: TeamId.team2,
          onChangeTeam: (_) {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('ليلى'), findsNWidgets(2));
    });
  });
}
