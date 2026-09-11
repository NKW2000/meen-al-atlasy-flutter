/// كود الغرفة — خمسة أرقام من عنوان IP المضيف.
library;

import 'dart:io';

/// تشفير عنوان المضيف كرمز غرفة: الثالث*256+الرابع، مع تعديد الأصفار إلى 5 أرقام.
String encodeRoomCode(InternetAddress ip) {
  if (ip.type != InternetAddressType.IPv4) {
    throw ArgumentError('Expected IPv4 address, got: ${ip.host}');
  }

  final parts = ip.host.split('.');
  final third = int.parse(parts[2]);
  final fourth = int.parse(parts[3]);
  final code = third * 256 + fourth;

  return code.toString().padLeft(5, '0');
}

/// فك تشفير رمز الغرفة — إرجاع عنوان IP للمضيف باستخدام الأول والثاني من عنوان اللاعب.
/// الرمز يجب أن يكون بالضبط 5 أرقام وقيمته لا تتجاوز 65535.
InternetAddress? decodeRoomCode(String code, InternetAddress myIp) {
  // يجب أن يكون الكود بالضبط 5 أرقام
  if (!RegExp(r'^\d{5}$').hasMatch(code)) {
    return null;
  }

  // تحويل إلى رقم والتحقق من عدم تجاوزه 65535
  final value = int.tryParse(code);
  if (value == null || value > 65535) {
    return null;
  }

  // استخراج الثالث والرابع من القيمة
  final fourth = value % 256;
  final third = value ~/ 256;

  // الحصول على الأول والثاني من عنوان اللاعب
  final myParts = myIp.host.split('.');
  if (myParts.length != 4) {
    return null;
  }

  final first = myParts[0];
  final second = myParts[1];

  // بناء عنوان IP الجديد
  return InternetAddress('$first.$second.$third.$fourth');
}
