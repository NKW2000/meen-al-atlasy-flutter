/// ترجمة الأخطاء التقنية لرسائل بلغة الناس — ولا نص استثناء بيوصل للشاشة.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/app/user_error.dart';
import 'package:meen_al_atlasy/ui/components/error_snackbar.dart';
import 'package:meen_al_atlasy/ui/theme.dart';

void main() {
  group('describeError', () {
    test('a timeout says the host did not answer and hints at the network', () {
      final e = describeError(TimeoutException('ws'), what: 'الاتصال بالمضيف');
      expect(e.title, 'الاتصال بالمضيف أخد وقت طويل وما ردّ حدا');
      expect(e.hint, contains('نفس الواي فاي'));
    });

    test('connection refused means the host is not hosting', () {
      final e = describeError(
        const SocketException('Connection refused', osError: OSError('refused', 111)),
      );
      expect(e.title, contains('المضيف ما عم يستقبل'));
      expect(e.hint, contains('يفتح الغرفة'));
    });

    test('unreachable means there is no network path', () {
      final e = describeError(
        const SocketException('Network is unreachable', osError: OSError('', 101)),
      );
      expect(e.title, 'ما في طريق للمضيف');
      expect(e.hint, contains('الواي فاي'));
    });

    test('address in use tells the host to restart the app', () {
      final e = describeError(
        const SocketException('bind failed', osError: OSError('in use', 10048)),
        what: 'بدء الاستضافة',
      );
      expect(e.title, contains('المنفذ مشغول'));
    });

    test('anything unknown still becomes a calm sentence, never the exception text', () {
      final e = describeError(ArgumentError('Invalid argument(s): xyz'));
      expect(e.title, 'صار خطأ غير متوقّع');
      expect(e.toString(), isNot(contains('xyz')));
      expect(e.toString(), isNot(contains('Exception')));
    });

    test('a UserError passes through untouched', () {
      const mine = UserError('عنوان', hint: 'تلميح');
      expect(describeError(mine), same(mine));
    });
  });

  group('ErrorBanner', () {
    testWidgets('shows the title, the hint and a dismiss button', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(feudApp(
        Center(
          child: ErrorBanner(
            message: 'ما في طريق للمضيف',
            hint: 'افتح الواي فاي أو نقطة الاتصال',
            onDismiss: () => dismissed++,
          ),
        ),
      ));

      expect(find.text('ما في طريق للمضيف'), findsOneWidget);
      expect(find.text('افتح الواي فاي أو نقطة الاتصال'), findsOneWidget);
      await tester.tap(find.text('تمام'));
      expect(dismissed, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the snackbar wrapper surfaces both lines and clears the error',
        (tester) async {
      var shown = 0;
      await tester.pumpWidget(feudApp(
        Scaffold(
          body: ErrorSnackbar(
            message: 'المضيف ما عم يستقبل — اللعبة مسكّرة عنده',
            hint: 'خلّي المضيف يفتح الغرفة، وبعدها جرّب تاني',
            onShown: () => shown++,
            child: const SizedBox.expand(),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('المضيف ما عم يستقبل — اللعبة مسكّرة عنده'), findsOneWidget);
      expect(find.text('خلّي المضيف يفتح الغرفة، وبعدها جرّب تاني'), findsOneWidget);
      expect(shown, 1);
    });
  });
}
