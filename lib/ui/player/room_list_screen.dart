/// لستة الغرف: كل مضيف قريب بيبيّن باسم غرفته، واللاعب بيدوس على وحدة
/// ليفوت فيها. منضل ندوّر وقت اللستة مفتوحة، فالغرف بتزيد وبتنقص لحالها.
///
/// منفّذ عن `RoomListScreen.kt` بالمشروع الأصلي (Kotlin). الإضافة الوحيدة
/// (مواصفة الواي فاي §3): سطر تحت اللستة بيقول إنه الكل لازم يكون على
/// نفس الشبكة.
library;

import 'package:flutter/material.dart';

import '../../network/room_discovery.dart';
import '../arabic_numerals.dart';
import '../components/brand_logo.dart';
import '../components/buttons.dart';
import '../components/stage.dart';
import '../host/host_lobby_screen.dart' show sameNetworkHint;
import '../responsive.dart';
import '../theme.dart';

class RoomListScreen extends StatelessWidget {
  final String playerName;
  final List<Room> rooms;
  final void Function(Room room) onPick;
  final VoidCallback onBack;

  /// «اكتب الكود» — طريق احتياطي لما ما تبيّن الغرفة أبداً (راوتر بيفلتر
  /// البثّ مثلاً). المضيف بيقرا الكود من شاشته. اختياري (المعرض ما بيمرّره).
  final VoidCallback? onEnterCode;

  const RoomListScreen({
    super.key,
    required this.playerName,
    required this.rooms,
    required this.onPick,
    required this.onBack,
    this.onEnterCode,
  });

  @override
  Widget build(BuildContext context) {
    if (isPortrait(context)) return _portrait(context);

    return StageBackground(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BrandBadge(em: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أي غرفة؟',
                        style: FeudText.headlineSmall(context).copyWith(color: FeudColors.gold),
                      ),
                      Text(
                        'أهلاً $playerName — اختار الغرفة اللي بدك تفوت فيها',
                        style: FeudText.bodyMedium(context).copyWith(color: FeudColors.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Pill(
                  text: rooms.isEmpty ? 'عم ندوّر...' : '${rooms.length.ar()} غرفة قريبة',
                  color: rooms.isEmpty ? FeudColors.stageAlt : FeudColors.lime,
                  textColor: rooms.isEmpty ? FeudColors.textMuted : FeudColors.ink,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: SecondaryButton(text: 'رجوع', onClick: onBack, accent: FeudColors.teal),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const GoldDivider(),
            const SizedBox(height: 10),
            Expanded(
              child: rooms.isEmpty
                  ? const _SearchingState()
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: 72,
                      ),
                      itemCount: rooms.length,
                      itemBuilder: (context, i) => _RoomRow(
                        key: ValueKey(rooms[i].endpointId),
                        room: rooms[i],
                        onClick: () => onPick(rooms[i]),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _NetworkHint()),
                if (onEnterCode != null) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: SecondaryButton(
                      text: 'اكتب كود الغرفة',
                      onClick: onEnterCode!,
                      accent: FeudColors.gold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// لستة الغرف بالوضع الطولي — نفس كرت التصميم.
  Widget _portrait(BuildContext context) {
    return StageBackground(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
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
                        'أي غرفة؟',
                        style: FeudText.titleLarge(context).copyWith(color: FeudColors.gold),
                      ),
                      Text(
                        'أهلاً $playerName — اختار الغرفة اللي بدك تفوت فيها',
                        style: FeudText.labelMedium(context).copyWith(color: FeudColors.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Pill(
                  text: rooms.isEmpty ? 'عم ندوّر' : '${rooms.length.ar()} غرف',
                  color: rooms.isEmpty ? FeudColors.stageAlt : FeudColors.lime,
                  textColor: rooms.isEmpty ? FeudColors.textMuted : FeudColors.ink,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const GoldDivider(),
            const SizedBox(height: 12),
            Expanded(
              child: rooms.isEmpty
                  ? const _SearchingState()
                  : ListView.separated(
                      itemCount: rooms.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _RoomRow(
                        key: ValueKey(rooms[i].endpointId),
                        room: rooms[i],
                        onClick: () => onPick(rooms[i]),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            _NetworkHint(),
            if (onEnterCode != null) ...[
              const SizedBox(height: 10),
              SecondaryButton(
                text: 'اكتب كود الغرفة',
                onClick: onEnterCode!,
                accent: FeudColors.gold,
              ),
            ],
            const SizedBox(height: 12),
            PrimaryButton(text: 'رجوع', onClick: onBack, color: FeudColors.teal),
          ],
        ),
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  final Room room;
  final VoidCallback onClick;

  const _RoomRow({super.key, required this.room, required this.onClick});

  @override
  Widget build(BuildContext context) {
    return CartoonSurface(
      color: FeudColors.stageAlt,
      borderWidth: 3,
      corner: FeudShape.block,
      shadow: 5,
      onClick: onClick,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const BrandBadge(em: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room.name,
                    style: FeudText.titleMedium(context).copyWith(color: FeudColors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'غرفة قريبة · جاهزة',
                    style: FeudText.labelMedium(context).copyWith(color: FeudColors.textMuted),
                  ),
                ],
              ),
            ),
            const Pill(text: 'فوت', color: FeudColors.lime),
          ],
        ),
      ),
    );
  }
}

/// حالة البحث: نقط بتنبض وسطر بيقول شو لازم يصير.
class _SearchingState extends StatefulWidget {
  const _SearchingState();

  @override
  State<_SearchingState> createState() => _SearchingStateState();
}

class _SearchingStateState extends State<_SearchingState> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 760))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = [FeudColors.gold, FeudColors.teal, FeudColors.pink];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scale,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, color) in colors.indexed) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Transform.scale(
                    scale: index.isEven ? _scale.value : 2 - _scale.value,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'عم ندوّر على غرف قريبة',
            style: FeudText.titleMedium(context).copyWith(color: FeudColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            'خلّي المضيف يفتح اللعبة ويضغط «بدء البث»، وتأكد إنه الاتنين '
            'على نفس الواي فاي',
            textAlign: TextAlign.center,
            style: FeudText.bodyMedium(context).copyWith(color: FeudColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// سطر الشبكة تحت اللستة — نفس النص اللي عند المضيف.
class _NetworkHint extends StatelessWidget {
  const _NetworkHint();

  @override
  Widget build(BuildContext context) => Text(
        sameNetworkHint,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FeudText.labelMedium(context).copyWith(color: FeudColors.textMuted),
      );
}
