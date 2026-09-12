/// اسم اللاعب — خانة وحدة بتفتح كيبورد الجهاز نفسه (بدون كيبورد خاص
/// بالتطبيق)، وتحتها زر بيضوي لما تكتب اسم. نفس الشكل بالوضعين.
///
/// منفّذ عن `PlayerJoinScreen.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/buttons.dart';
import '../components/stage.dart';
import '../theme.dart';

/// أطول اسم مسموح — حتى يضل يبيّن كامل بلستة اللاعبين.
const int maxPlayerName = 14;

class PlayerJoinScreen extends StatefulWidget {
  final void Function(String name) onJoinConfirmed;

  const PlayerJoinScreen({super.key, required this.onJoinConfirmed});

  @override
  State<PlayerJoinScreen> createState() => _PlayerJoinScreenState();
}

class _PlayerJoinScreenState extends State<PlayerJoinScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  bool get _ready => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    // الكيبورد بيفتح لحاله أول ما تطلع الشاشة — نفس `requestFocus()`
    // + `keyboard.show()` بالكوتلن.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_ready) widget.onJoinConfirmed(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    // نفس `imePadding()`: المحتوى بينزاح فوق الكيبورد بدل ما ينغطّى.
    final imeBottom = MediaQuery.viewInsetsOf(context).bottom;

    return StageBackground(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: imeBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'شو اسمك؟',
                      style: FeudText.displaySmall(context).copyWith(color: FeudColors.gold),
                    ),
                    const SizedBox(height: 18),
                    BlockSkin(
                      color: FeudColors.cream,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        // TextField بدها Material فوقها — الشاشة بتوفّره
                        // لحالها بدل ما تتكل على Scaffold المسار.
                        child: Material(
                          type: MaterialType.transparency,
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            maxLength: maxPlayerName,
                            maxLines: 1,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _confirm(),
                            inputFormatters: [_trimStart],
                            style: FeudText.headlineSmall(context).copyWith(color: FeudColors.ink),
                            cursorColor: FeudColors.ink,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              counterText: '',
                              hintText: 'اكتب اسمك',
                              hintStyle: FeudText.headlineSmall(context)
                                  .copyWith(color: FeudColors.ink.withValues(alpha: 0.35)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'بعد ما تفوت بتختار فريقك من اللوبي',
                      style: FeudText.bodyLarge(context).copyWith(color: FeudColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (_ready)
                PrimaryButton(text: 'يلا نلعب', onClick: _confirm, color: FeudColors.lime)
              else
                BlockSkin(
                  color: FeudColors.panelDark,
                  border: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        'اكتب اسمك',
                        style: FeudText.titleLarge(context).copyWith(color: FeudColors.outlineSoft),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `name = it.trimStart()` بالكوتلن — بدون مسافات بأول الاسم. لازم نقصّ
/// الـ selection لطول النص الجديد وإلا بترمي (RangeError) لما يكتب
/// المستخدم مسافة بحقل فاضي.
final TextInputFormatter _trimStart = TextInputFormatter.withFunction((oldValue, newValue) {
  final trimmed = newValue.text.trimLeft();
  final removed = newValue.text.length - trimmed.length;
  final rawEnd = newValue.selection.end;
  final newEnd = rawEnd < 0 ? trimmed.length : (rawEnd - removed).clamp(0, trimmed.length);
  return TextEditingValue(
    text: trimmed,
    selection: TextSelection.collapsed(offset: newEnd),
  );
});
