/// عناوين البثّ على الشبكة المحلية — مشتركة بين منارة المضيف
/// ([RoomBeacon]) وبحث اللاعب ([RoomDiscovery]).
library;

import 'dart:io';

/// البثّ العام — بيوصل لكل الشبكة، بس بعض الراوترات وأنظمة توفير الطاقة
/// بتفلتره أو بتأخّره.
final InternetAddress limitedBroadcast = InternetAddress('255.255.255.255');

/// البثّ الموجّه لكل واجهة IPv4 (واي فاي / نقطة اتصال): `x.y.z.255`.
///
/// منفترض /24 لأنه `dart:io` ما بيعرّض قناع الشبكة أبداً، و/24 هو الشائع
/// بالشبكات المنزلية ونقاط الاتصال. على شبكة /16 أو /22 هالعنوان مش عنوان
/// البثّ الصح وحزمه بتضيع — ولهيك في مسار تاني (سؤال اللاعب وجواب المضيف
/// المباشر بـ[roomProbePort]) ما بيعتمد على البثّ الموجّه أصلاً.
Future<List<InternetAddress>> directedBroadcasts() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    return [
      for (final iface in interfaces)
        for (final addr in iface.addresses)
          if (!addr.isLoopback && !addr.address.startsWith('10.0.2.'))
            InternetAddress(
              '${addr.address.substring(0, addr.address.lastIndexOf('.'))}.255',
            ),
    ];
  } catch (_) {
    // ما في شبكة هلق — البثّ العام لحاله.
    return const [];
  }
}
