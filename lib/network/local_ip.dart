/// أفضل عنوان IPv4 محلي على شبكة Wi-Fi أو نقطة اتصال — يستعمله المضيف
/// لحساب رمز الغرفة، واللاعب لعرضه.
library;

import 'dart:io';

/// بيرجّع أفضل عنوان IPv4 محلي مناسب للعب — واجهة Wi-Fi أو hotspot، مش
/// محاكي (10.0.2.x) ومش VPN/loopback. بيرجّع null لو ما لقى شي مناسب.
Future<InternetAddress?> wifiIPv4() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: false,
  );

  InternetAddress? best;
  int bestScore = -1;

  for (final iface in interfaces) {
    final name = iface.name.toLowerCase();

    if (name.contains('rmnet') || name.contains('tun') || name.contains('lo')) {
      continue;
    }

    final score = (name.startsWith('wlan') ||
            name.startsWith('ap') ||
            name.startsWith('swlan') ||
            name.startsWith('en0') ||
            name.startsWith('bridge'))
        ? 2
        : 1;

    for (final addr in iface.addresses) {
      if (addr.address.startsWith('10.0.2.')) continue; // محاكي Android
      if (score > bestScore) {
        bestScore = score;
        best = addr;
      }
    }
  }

  return best;
}
