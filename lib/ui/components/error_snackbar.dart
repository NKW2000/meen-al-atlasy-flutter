/// بيعرض آخر خطأ من المتحكّم بشريط سفلي (SnackBar) مرة وحدة، وبعدها
/// بينادي [onShown] حتى يمسحه المتحكّم — نفس `ErrorSnackbar` بـ
/// `FeudNavGraph.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

class ErrorSnackbar extends StatefulWidget {
  /// الرسالة الحالية — `null` لما ما في خطأ.
  final String? message;
  final VoidCallback onShown;
  final Widget child;

  const ErrorSnackbar({
    super.key,
    required this.message,
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
    if (widget.message != oldWidget.message) _maybeShow();
  }

  void _maybeShow() {
    final message = widget.message;
    if (message == null) return;
    // بعد الإطار الحالي — `ScaffoldMessenger` ما بيقبل عرض من جوّا build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
      widget.onShown();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
