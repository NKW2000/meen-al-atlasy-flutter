/// لوبي اللاعب: اسمه ورقمه وفريقه، ومين معه بالفريق، وزر يبدّل فيه فريقه
/// قبل ما تبلّش اللعبة.
///
/// منفّذ عن `PlayerLobbyScreen` + `TeamRoster` بـ`PlayerScreen.kt`
/// بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../../feedback/game_feedback.dart';
import '../../game/models.dart';
import '../arabic_numerals.dart';
import '../components/buttons.dart';
import '../components/seat_badge.dart';
import '../components/stage.dart';
import '../components/strikes.dart';
import '../responsive.dart';
import '../theme.dart';

class PlayerLobbyScreen extends StatelessWidget {
  final GameState state;
  final String? playerId;
  final TeamId? teamId;
  final void Function(TeamId team) onChangeTeam;

  /// كود الغرفة (٥ أرقام) — بيبيّن حتى يعطيه اللاعب لغيره. اختياري.
  final String? roomCode;

  const PlayerLobbyScreen({
    super.key,
    required this.state,
    required this.playerId,
    required this.teamId,
    required this.onChangeTeam,
    this.roomCode,
  });

  @override
  Widget build(BuildContext context) {
    final me = state.player(playerId);
    final other = teamId?.other;
    final portrait = isPortrait(context);

    final waiting = Text(
      'بانتظار المضيف يبلّش',
      style: FeudText.titleMedium(context).copyWith(color: FeudColors.gold),
      maxLines: 1,
    );
    final code = roomCode;
    final codePill = code == null
        ? null
        : Pill(
            text: 'كود الغرفة: ${code.arDigits()}',
            color: FeudColors.gold,
            textColor: FeudColors.ink,
          );

    return Container(
      color: FeudColors.stage,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بالطولي الاسم بسطر والحالة بسطر تحته — ما بينقص الاسم.
              if (portrait) ...[
                Row(
                  children: [
                    if (me != null) ...[
                      SeatBadge(seat: me.seat, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          me.name,
                          style: FeudText.headlineSmall(context).copyWith(color: FeudColors.cream),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: waiting),
                    ?codePill,
                  ],
                ),
              ] else
                Row(
                  children: [
                    if (me != null) ...[
                      SeatBadge(seat: me.seat, size: 34),
                      const SizedBox(width: 10),
                      Text(
                        me.name,
                        style: FeudText.headlineSmall(context).copyWith(color: FeudColors.cream),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    if (codePill != null) ...[codePill, const SizedBox(width: 10)],
                    waiting,
                  ],
                ),
              const SizedBox(height: 14),

              // الفرق بأسماء المضيف: دوس على فريق حتى تفوت فيه. بالطولي
              // بيصيروا فوق بعض وأسماء اللاعبين بعمودين — زي التصميم.
              Expanded(
                child: portrait
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, id) in TeamId.values.indexed) ...[
                            if (index > 0) const SizedBox(height: 16),
                            Expanded(
                              child: _TeamRoster(
                                state: state,
                                teamId: id,
                                mine: id == teamId,
                                onClick: () {
                                  if (id == teamId) return;
                                  GameFeedbackScope.maybeOf(context)?.play(Cue.teamSwitch);
                                  onChangeTeam(id);
                                },
                                twoColumns: true,
                              ),
                            ),
                          ],
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, id) in TeamId.values.indexed) ...[
                            if (index > 0) const SizedBox(width: 12),
                            Expanded(
                              child: _TeamRoster(
                                state: state,
                                teamId: id,
                                mine: id == teamId,
                                onClick: () {
                                  if (id == teamId) return;
                                  GameFeedbackScope.maybeOf(context)?.play(Cue.teamSwitch);
                                  onChangeTeam(id);
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: 12),
              Text(
                other == null ? '' : 'دوس على الفريق التاني إذا بدك تبدّل',
                textAlign: TextAlign.center,
                style: FeudText.bodyLarge(context).copyWith(color: FeudColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// أسماء فريق مرتّبة برقم كل لاعب.
class _TeamRoster extends StatelessWidget {
  final GameState state;
  final TeamId teamId;
  final bool mine;
  final VoidCallback onClick;
  final bool twoColumns;

  const _TeamRoster({
    required this.state,
    required this.teamId,
    required this.mine,
    required this.onClick,
    this.twoColumns = false,
  });

  @override
  Widget build(BuildContext context) {
    final team = state.teams[teamId];
    final roster = state.playersOf(teamId);
    final rows = twoColumns
        ? _chunked(roster, 2)
        : [
            for (final p in roster) [p],
          ];

    return CartoonSurface(
      // الفريقين بلون النظام بالضبط — «فريقك» والحدّ الذهبي هني اللي
      // بيميّزوا فريقك، مش تخفيف اللون.
      color: teamId.color(),
      corner: FeudShape.block,
      shadow: 7,
      onClick: onClick,
      child: Padding(
        padding: EdgeInsets.all(twoColumns ? 18 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    team?.name ?? 'فريق',
                    style: FeudText.titleLarge(context).copyWith(color: teamId.inkColor()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (mine)
                  Text(
                    'فريقك',
                    style: FeudText.labelLarge(context).copyWith(color: teamId.inkColor()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    for (final (index, player) in row.indexed) ...[
                      if (index > 0) const SizedBox(width: 10),
                      _rosterEntry(context, player),
                    ],
                    if (twoColumns && row.length == 1) const Spacer(),
                  ],
                ),
              ),
            if (roster.isEmpty)
              Text(
                'لسا ما فات حدا',
                style: FeudText.bodyMedium(context).copyWith(color: FeudColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rosterEntry(BuildContext context, Player player) {
    final entry = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SeatBadge(seat: player.seat, size: twoColumns ? 30 : 24),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            player.name,
            style: FeudText.titleMedium(context).copyWith(color: teamId.inkColor()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    return twoColumns ? Expanded(child: entry) : entry;
  }
}

List<List<T>> _chunked<T>(List<T> list, int size) => [
  for (var i = 0; i < list.length; i += size)
    list.sublist(i, i + size > list.length ? list.length : i + size),
];
