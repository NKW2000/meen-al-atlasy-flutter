/// بيعرض آخر خطأ من المتحكّم ببلوك بستايل اللعبة (وردي بحدّ حبري): عنوان
/// بلغة الناس، تلميح شو يعمل، وزر «تمام». بيطلع من تحت، بيروح لحاله بعد
/// ثواني أو بالضغطة، وبعدها بينادي [onShown] حتى يمسحه المتحكّم.
///
/// نص الاستثناء التقني ما بيوصل لهون أبداً — المتحكّمات بتترجمه قبل
/// (`describeError`).
library;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'stage.dart';

class ErrorSnackbar extends StatefulWidget {
  /// الرسالة الحالية — `null` لما ما في خطأ.
  final String? message;

  /// تلميح شو يعمل المستخدم — اختياري.
  final String? hint;
  final VoidCallback onShown;
  final Widget child;

  const ErrorSnackbar({
    super.key,
    required this.message,
    this.hint,
    required this.onShown,
    required this.child,
  });

  @override
  State<ErrorSnackbar> createState() => _ErrorSnackbarState();
}

class _ErrorSnackbarState extends State<ErrorSnackbar> {
  @override
  void initState() {
    super.initState();
    _maybeShow();
  }

  @override
  void didUpdateWidget(ErrorSnackbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message || widget.hint != oldWidget.hint) {
      _maybeShow();
    }
  }

  void _maybeShow() {
    final message = widget.message;
    if (message == null) return;
    final hint = widget.hint;
    // بعد الإطار الحالي — `ScaffoldMessenger` ما بيقبل عرض من جوّا build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          duration: const Duration(seconds: 8),
          content: ErrorBanner(
            message: message,
            hint: hint,
            onDismiss: messenger.hideCurrentSnackBar,
          ),
        ),
      );
      widget.onShown();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// بلوك الخطأ نفسه — مفصول حتى ينختبر ويتعرض بالمعرض.
class ErrorBanner extends StatelessWidget {
  final String message;
  final String? hint;
  final VoidCallback onDismiss;

  const ErrorBanner({
    super.key,
    required this.message,
    this.hint,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return BlockSkin(
      color: FeudColors.pink,
      border: 3,
      shadow: 5,
      corner: FeudShape.block,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // علامة تعجّب بدائرة كريمية — نفس روح أرقام الخانات.
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: FeudColors.cream,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: FeudColors.ink, width: 3)),
              ),
              child: Text(
                '!',
                style: FeudText.titleLarge(context).copyWith(color: FeudColors.ink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: FeudText.titleMedium(context).copyWith(color: FeudColors.cream),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: FeudText.bodyMedium(context)
                          .copyWith(color: FeudColors.cream.withValues(alpha: 0.85)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            CartoonSurface(
              color: FeudColors.cream,
              borderWidth: 3,
              corner: 10,
              shadow: 3,
              onClick: onDismiss,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  'تمام',
                  style: FeudText.labelLarge(context).copyWith(color: FeudColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
