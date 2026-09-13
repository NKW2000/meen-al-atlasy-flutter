/// لوبي المضيف. كل إشي بيدخل بشاشة وحدة بدون تمرير: عمودين للفريقين،
/// وسطر واحد فوق وسطر أزرار تحت.
///
/// منفّذ عن `HostSetupScreen.kt` بالمشروع الأصلي (Kotlin). الإضافة
/// الوحيدة (مواصفة الواي فاي §3): تحت اسم الغرفة عنوان الواي فاي —
/// بديل «الأجهزة القريبة» — وسطر بيقول إنه الكل لازم يكون على
/// نفس الشبكة.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../components/buttons.dart';
import '../components/seat_badge.dart';
import '../arabic_numerals.dart';
import '../components/stage.dart';
import '../components/strikes.dart';
import '../responsive.dart';
import '../theme.dart';

/// السطر اللي بيطلع بالشاشتين (لوبي المضيف ولستة الغرف) — نفس النص
/// بالضبط.
const String sameNetworkHint = 'لازم الكل يكون على نفس الواي فاي أو نقطة اتصال المضيف';

/// لما ما في عنوان واي فاي: نفس رسالة `PlayerController.enterCode`.
const String noWifiHint = 'افتح الواي فاي أو نقطة الاتصال';

void _noMove(String _, TeamId _) {}

class HostLobbyScreen extends StatelessWidget {
  final String roomName;
  final Map<TeamId, TeamState> teams;
  final List<Player> players;
  final bool advertising;
  final int minPerTeam;

  /// عنوان الواي فاي تبع المضيف — `null` لما ما في شبكة، وساعتها ما
  /// بينفع نبلّش بث.
  final InternetAddress? ip;
  final VoidCallback onStartHosting;
  final VoidCallback onBeginGame;
  final void Function(String playerId, TeamId to) onMovePlayer;

  const HostLobbyScreen({
    super.key,
    required this.roomName,
    required this.teams,
    required this.players,
    required this.advertising,
    required this.minPerTeam,
    required this.ip,
    required this.onStartHosting,
    required this.onBeginGame,
    this.onMovePlayer = _noMove,
  });

  @override
  Widget build(BuildContext context) {
    final ready = TeamId.values.every(
      (team) => players.where((p) => p.teamId == team && p.connected).length >= minPerTeam,
    );
    final portrait = isPortrait(context);
    final canHost = ip != null;

    final buttons = [
      SecondaryButton(
        text: advertising ? 'البث شغّال' : 'بدء البث',
        onClick: onStartHosting,
        enabled: !advertising && canHost,
      ),
      PrimaryButton(
        text: 'ابدأ اللعبة',
        onClick: onBeginGame,
        enabled: ready,
        color: FeudColors.lime,
      ),
    ];

    return StageBackground(
      contentPadding: stagePadding(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مين معنا؟',
                        style: FeudText.headlineSmall(context).copyWith(color: FeudColors.gold),
                      ),
                      Text(
                        'كل لاعب بيفتح التطبيق ويختار «انضمام كلاعب»',
                        style: FeudText.bodyMedium(context).copyWith(color: FeudColors.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (advertising) const _BroadcastBadge() else const SizedBox(width: 1),
              ],
            ),
            const SizedBox(height: 8),
            _NetworkStrip(roomName: roomName, ip: ip),
            const SizedBox(height: 10),
            Expanded(
              child: portrait
                  // طولي: فريق فوق فريق بتمرير، والأزرار ملزوقة تحت.
                  ? SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final (index, teamId) in TeamId.values.indexed) ...[
                            if (index > 0) const SizedBox(height: 10),
                            _TeamColumn(
                              team: teams[teamId],
                              teamId: teamId,
                              players: players.where((p) => p.teamId == teamId).toList(),
                              onMovePlayer: onMovePlayer,
                              expand: false,
                            ),
                          ],
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, teamId) in TeamId.values.indexed) ...[
                          if (index > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _TeamColumn(
                              team: teams[teamId],
                              teamId: teamId,
                              players: players.where((p) => p.teamId == teamId).toList(),
                              onMovePlayer: onMovePlayer,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              ready ? 'جاهزين — يلا نبلّش' : 'بدنا لاعب بكل فريق عالأقل',
              textAlign: TextAlign.center,
              style: FeudText.titleSmall(context)
                  .copyWith(color: ready ? FeudColors.lime : FeudColors.textMuted),
            ),
            const SizedBox(height: 8),
            if (portrait)
              Row(
                children: [
                  Expanded(child: buttons[0]),
                  const SizedBox(width: 12),
                  Expanded(child: buttons[1]),
                ],
              )
            else
              Row(
                children: [
                  SizedBox(width: 240, child: buttons[0]),
                  const Spacer(),
                  SizedBox(width: 240, child: buttons[1]),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// اسم الغرفة، وجنبه عنوان الواي فاي بشارة، وسطر الشبكة.
/// بدون واي فاي: شارة وردية بتطلب تشغيله بدل العنوان.
class _NetworkStrip extends StatelessWidget {
  final String roomName;
  final InternetAddress? ip;

  const _NetworkStrip({required this.roomName, required this.ip});

  @override
  Widget build(BuildContext context) {
    final ip = this.ip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              roomName,
              style: FeudText.titleMedium(context).copyWith(color: FeudColors.cream),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (ip == null)
              const Pill(text: noWifiHint, color: FeudColors.pink, textColor: FeudColors.cream)
            else
              Pill(
                text: 'الواي فاي: ${ip.address}',
                color: FeudColors.stageAlt,
                textColor: FeudColors.cream,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          sameNetworkHint,
          style: FeudText.labelMedium(context).copyWith(color: FeudColors.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// نقطة بتنبض بتقول إنه البث شغّال.
class _BroadcastBadge extends StatefulWidget {
  const _BroadcastBadge();

  @override
  State<_BroadcastBadge> createState() => _BroadcastBadgeState();
}

class _BroadcastBadgeState extends State<_BroadcastBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.15).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulse,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: FeudColors.lime,
              shape: BoxShape.circle,
              border: Border.all(color: FeudColors.ink, width: 2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Pill(text: 'بانتظار اللاعبين', color: FeudColors.gold),
      ],
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final TeamState? team;
  final TeamId teamId;
  final List<Player> players;
  final void Function(String, TeamId) onMovePlayer;

  /// بالوضع الطولي الكرت بياخد ارتفاع محتواه بس — لأنه جوّا تمرير.
  final bool expand;

  const _TeamColumn({
    required this.team,
    required this.teamId,
    required this.players,
    required this.onMovePlayer,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = teamId.color();
    final joined = players.where((p) => p.connected).length;

    final Widget body;
    if (players.isEmpty) {
      final waiting = Center(
        child: Text(
          'بانتظار الاتصال...',
          style: FeudText.bodyLarge(context).copyWith(color: FeudColors.textMuted),
        ),
      );
      body = expand ? Expanded(child: waiting) : SizedBox(height: 90, child: waiting);
    } else if (expand) {
      // أفقي: قائمة بتتمرّر لحالها — تضل داخل الشاشة مهما زاد العدد.
      body = Expanded(
        child: ListView.builder(
          itemCount: players.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _PlayerRow(
              player: players[i],
              teamId: teamId,
              onMove: () => onMovePlayer(players[i].id, teamId.other),
            ),
          ),
        ),
      );
    } else {
      // طولي: الكرت كله جوّا تمرير الشاشة، فاللستة عادية.
      body = Column(
        children: [
          for (final player in players)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _PlayerRow(
                player: player,
                teamId: teamId,
                onMove: () => onMovePlayer(player.id, teamId.other),
              ),
            ),
        ],
      );
    }

    return CartoonSurface(
      color: joined > 0 ? color : FeudColors.ink.withValues(alpha: 0.35),
      corner: FeudShape.block,
      shadow: 7,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    team?.name ?? 'فريق',
                    style: FeudText.titleLarge(context)
                        .copyWith(color: joined > 0 ? teamId.inkColor() : color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${joined.ar()} لاعب',
                  style: FeudText.labelLarge(context).copyWith(
                    color: joined > 0
                        ? teamId.inkColor().withValues(alpha: 0.8)
                        : FeudColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final Player player;
  final TeamId teamId;
  final VoidCallback onMove;

  const _PlayerRow({required this.player, required this.teamId, required this.onMove});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // رقم اللاعب — هو نفسه رقم خصمه بالفريق التاني.
        SeatBadge(seat: player.seat, dim: !player.connected),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            player.name,
            style: FeudText.titleMedium(context)
                .copyWith(color: player.connected ? teamId.inkColor() : FeudColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // نقل اللاعب للفريق التاني قبل ما تبلّش اللعبة.
        CartoonSurface(
          color: FeudColors.gold,
          borderWidth: 3,
          corner: FeudShape.block,
          shadow: 3,
          onClick: onMove,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              'بدّل ⇄',
              style: FeudText.labelSmall(context).copyWith(color: FeudColors.ink),
            ),
          ),
        ),
      ],
    );
  }
}
