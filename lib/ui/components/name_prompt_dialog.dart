/// كتابة اسم قصير بكيبورد الجهاز — خانة كريمية وزرّين تحتها. ما عاد في
/// كيبورد خاص بالتطبيق.
///
/// منفّذ عن `components/NamePromptDialog.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'buttons.dart';
import 'stage.dart';

class NamePromptDialog extends StatefulWidget {
  final String title;
  final String initial;
  final int maxLength;
  final ValueChanged<String> onConfirm;
  final VoidCallback onDismiss;

  const NamePromptDialog({
    super.key,
    required this.title,
    required this.initial,
    this.maxLength = 18,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  State<NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<NamePromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
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

  void _submitIfValid() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) widget.onConfirm(value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: FeudColors.ink.withValues(alpha: 0.86),
        alignment: Alignment.center,
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          child: CartoonSurface(
            color: FeudColors.stage,
            borderWidth: 4,
            corner: FeudShape.block,
            shadow: 8,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: FeudText.titleLarge(context).copyWith(color: FeudColors.gold),
                  ),
                  const SizedBox(height: 12),
                  BlockSkin(
                    color: FeudColors.cream,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        maxLength: widget.maxLength,
                        maxLines: 1,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            return newValue.copyWith(text: newValue.text.trimLeft());
                          }),
                        ],
                        style: FeudText.headlineSmall(context).copyWith(color: FeudColors.ink),
                        cursorColor: FeudColors.ink,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          hintText: 'اكتب الاسم',
                          hintStyle: FeudText.headlineSmall(context)
                              .copyWith(color: FeudColors.ink.withValues(alpha: 0.35)),
                        ),
                        onSubmitted: (_) => _submitIfValid(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          text: 'إلغاء',
                          onClick: widget.onDismiss,
                          accent: FeudColors.pink,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, _) => PrimaryButton(
                            text: 'تمام',
                            onClick: _submitIfValid,
                            color: FeudColors.lime,
                            enabled: value.text.trim().isNotEmpty,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
