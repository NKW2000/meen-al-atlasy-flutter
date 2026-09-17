/// كود الغرفة — خمسة أرقام من عنوان IP المضيف. (ما عاد يبيّن بالواجهة —
/// بقي للمتحكّم والاختبارات.)
library;

import 'dart:io';
import 'dart:typed_data';

/// تشفير عنوان المضيف كرمز غرفة: الثالث*256+الرابع، مع تعديد الأصفار إلى 5 أرقام.
/// من بايتات العنوان مباشرة — `host` ممكن يرجع اسم جهاز مش عنوان على بعض
/// الأجهزة، وهاد اللي كان يكسر لوبي المضيف.
String encodeRoomCode(InternetAddress ip) {
  if (ip.type != InternetAddressType.IPv4) {
    throw ArgumentError('Expected IPv4 address, got: ${ip.address}');
  }
  final bytes = ip.rawAddress;
  final code = bytes[2] * 256 + bytes[3];
  return code.toString().padLeft(5, '0');
}

/// أرقام عربية (٠-٩) أو فارسية (۰-۹) → ASCII. الكود بيبيّن عند المضيف
/// بأرقام عربية، والكيبورد العربي بيكتبها هيك — لازم تنقبل.
String asciiDigits(String s) => s.replaceAllMapped(
      RegExp('[٠-٩۰-۹]'),
      (m) {
        final c = m[0]!.codeUnitAt(0);
        final base = c >= 0x06F0 ? 0x06F0 : 0x0660;
        return String.fromCharCode(0x30 + (c - base));
      },
    );

/// فك تشفير رمز الغرفة — إرجاع عنوان IP للمضيف باستخدام الأول والثاني من عنوان اللاعب.
/// الرمز يجب أن يكون بالضبط 5 أرقام (عربي أو ASCII) وقيمته لا تتجاوز 65535.
InternetAddress? decodeRoomCode(String rawCode, InternetAddress myIp) {
  final code = asciiDigits(rawCode.trim());
  if (!RegExp(r'^[0-9]{5}$').hasMatch(code)) return null;
  final value = int.tryParse(code);
  if (value == null || value > 65535) return null;
  if (myIp.type != InternetAddressType.IPv4) return null;
  final mine = myIp.rawAddress;
  return InternetAddress.fromRawAddress(
    Uint8List.fromList([mine[0], mine[1], value ~/ 256, value % 256]),
  );
}
