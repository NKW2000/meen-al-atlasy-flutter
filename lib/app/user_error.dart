/// رسالة خطأ بلغة الناس — مش نص الاستثناء.
///
/// كل مشكلة تقنية (مهلة انتهت، ما في شبكة، المضيف رفض الاتصال…) بتتحوّل
/// لعنوان قصير وتلميح شو يعمل اللاعب. نص الاستثناء نفسه ما بيوصل للشاشة
/// أبداً — كان يطلع «SocketException: OS Error: Connection refused, errno =
/// 111» بشريط وردي.
library;

import 'dart:async';
import 'dart:io';

class UserError {
  /// شو صار — سطر واحد.
  final String title;

  /// شو يعمل — اختياري.
  final String? hint;

  const UserError(this.title, {this.hint});

  @override
  String toString() => hint == null ? title : '$title — $hint';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserError && other.title == title && other.hint == hint);

  @override
  int get hashCode => Object.hash(title, hint);
}

/// نفس التلميح بكل مشاكل الشبكة — الحل واحد بالغالب.
const String _sameNetworkHint = 'تأكد إنكم على نفس الواي فاي، أو جرّب كود الغرفة';

/// بيترجم استثناء تقني لرسالة مفهومة. [what] بيقول شو كنا عم نحاول نعمل
/// («الاتصال بالمضيف»، «بدء الاستضافة»…) حتى يكون العنوان بمحله.
UserError describeError(Object error, {String what = 'الاتصال'}) {
  if (error is UserError) return error;

  if (error is TimeoutException) {
    return UserError('$what أخد وقت طويل وما ردّ حدا', hint: _sameNetworkHint);
  }

  if (error is SocketException) {
    final code = error.osError?.errorCode;
    final text = error.message.toLowerCase();
    // منفذ محجوز — استضافة سابقة لسا ما سكّرت.
    if (code == 98 || code == 10048 || text.contains('address already in use')) {
      return UserError(
        'المنفذ مشغول من تطبيق تاني',
        hint: 'سكّر التطبيق وافتحه من جديد',
      );
    }
    // المضيف موجود بس ما في خادم عنده (اللعبة مسكّرة).
    if (code == 111 || code == 10061 || text.contains('refused')) {
      return UserError(
        'المضيف ما عم يستقبل — اللعبة مسكّرة عنده',
        hint: 'خلّي المضيف يفتح الغرفة، وبعدها جرّب تاني',
      );
    }
    // ما في شبكة أصلاً، أو الجهاز التاني مش على نفسها.
    if (code == 101 ||
        code == 113 ||
        code == 10051 ||
        code == 10065 ||
        text.contains('unreachable') ||
        text.contains('no route')) {
      return UserError('ما في طريق للمضيف', hint: 'افتح الواي فاي أو نقطة الاتصال');
    }
    return UserError('فشل $what', hint: _sameNetworkHint);
  }

  if (error is WebSocketException || error is HttpException || error is HandshakeException) {
    return UserError('فشل $what', hint: _sameNetworkHint);
  }

  if (error is StateError) {
    return const UserError('صار خطأ بالتطبيق', hint: 'ارجع للشاشة الرئيسية وجرّب تاني');
  }

  return UserError('صار خطأ غير متوقّع', hint: 'جرّب مرة تانية');
}
