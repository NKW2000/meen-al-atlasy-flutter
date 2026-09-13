/// اكتشاف الغرف — بيسمع بثّ UDP من [RoomBeacon] ويجمّع الغرف الظاهرة حالياً
/// على الشبكة، بديل اكتشاف Nearby Connections بالنسخة الأصلية.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'multicast_lock.dart';
import 'room_beacon.dart';

/// غرفة مكتشَفة على الشبكة — مضيف واحد بعنوانه ومنفذه.
class Room {
  final String name;
  final InternetAddress host;
  final int port;

  Room(this.name, this.host, this.port);

  /// معرّف فريد للغرفة — عنوان المضيف + منفذه.
  String get endpointId => '${host.address}:$port';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Room && other.endpointId == endpointId);

  @override
  int get hashCode => endpointId.hashCode;
}

/// مدة بقاء الغرفة "حيّة" بدون بث جديد قبل ما تُعتبر منتهية.
const Duration _roomTtl = Duration(seconds: 4);

/// بيسمع بثّ [RoomBeacon] عبر UDP، ويحدّث [rooms] بالغرف الظاهرة حالياً —
/// الغرف اللي ما وصلها بث جديد خلال [_roomTtl] بتنشال تلقائياً.
class RoomDiscovery {
  /// عنوان الربط — افتراضياً كل الواجهات، وبيتغيّر لـ loopback بالاختبارات.
  final InternetAddress bindAddress;

  RoomDiscovery({InternetAddress? bindAddress})
      : bindAddress = bindAddress ?? InternetAddress.anyIPv4;

  final ValueNotifier<List<Room>> rooms = ValueNotifier<List<Room>>([]);

  RawDatagramSocket? _socket;
  Timer? _timer;
  final Map<String, (Room, DateTime)> _seen = {};

  /// بيبدأ الاستماع لبثّ الغرف.
  Future<void> start() async {
    if (_socket != null) return; // شغّال أصلاً — ما منعمل شي.
    await acquireMulticastLock();

    final sock = await RawDatagramSocket.bind(
      bindAddress,
      roomBeaconPort,
      reuseAddress: true,
      reusePort: false,
    );
    sock.broadcastEnabled = true;
    _socket = sock;

    sock.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = sock.receive();
      if (dg == null) return;
      handlePacket(dg.address, dg.data);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _publish());
  }

  /// حزمة منارة وصلت من [from]. عامة حتى تنختبر بدون مقابس.
  ///
  /// المفتاح هو معرّف جلسة المضيف (`id`) مش عنوان المرسل: نفس المضيف ممكن
  /// يبثّ من أكتر من واجهة (واي فاي + نقطة اتصال) أو على أكتر من عنوان
  /// بثّ، فبتوصل حزمه من عناوين مختلفة — وبدون المعرّف بتطلع الغرفة
  /// مكرّرة. ومضيف أعاد الاستضافة (معرّف جديد، نفس العنوان والمنفذ) بياخد
  /// مكان مدخله القديم بدل ما يظهر مرتين.
  @visibleForTesting
  void handlePacket(InternetAddress from, List<int> data) {
    try {
      final j = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
      final room = Room(j['room'] as String, from, j['port'] as int);
      final key = (j['id'] as String?) ?? room.endpointId;
      _seen.removeWhere((k, entry) => k != key && entry.$1.endpointId == room.endpointId);
      _seen[key] = (room, DateTime.now());
      _publish();
    } catch (_) {
      // حزمة مشوّهة — نتجاهلها.
    }
  }

  void _publish() {
    final cutoff = DateTime.now().subtract(_roomTtl);
    _seen.removeWhere((_, entry) => entry.$2.isBefore(cutoff));
    final sorted = _seen.values.map((e) => e.$1).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    // ما منحدّث القيمة إلا إذا فعلاً تغيّرت — حتى ما نطلق مستمعين (والواجهة)
    // كل ثانية بلا داعي لما القائمة نفسها.
    if (!listEquals(rooms.value, sorted)) {
      rooms.value = sorted;
    }
  }

  /// بيوقف الاستماع ويسكّر المقبس.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
    _seen.clear();
    rooms.value = const [];
    await releaseMulticastLock();
  }
}
