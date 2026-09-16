/// اكتشاف الغرف — بيسمع بثّ UDP من [RoomBeacon] ويجمّع الغرف الظاهرة حالياً
/// على الشبكة، بديل اكتشاف Nearby Connections بالنسخة الأصلية.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'broadcast_targets.dart';
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
const Duration _roomTtl = Duration(seconds: 6);

/// بيسمع بثّ [RoomBeacon] عبر UDP، ويحدّث [rooms] بالغرف الظاهرة حالياً —
/// الغرف اللي ما وصلها بث جديد خلال [_roomTtl] بتنشال تلقائياً.
///
/// وكل ثانية كمان **بيسأل**: بيبعت حزمة صغيرة على [roomProbePort]، والمضيف
/// بيجاوبها مباشرة (unicast) على منفذنا. هاد المسار هو اللي بيخلّي الغرفة
/// تبيّن على الأجهزة اللي ما بيوصلها بثّ المضيف — توفير الطاقة بالأندرويد
/// بيرمي حزم البثّ الواصلة، وكتير راوترات بتفلترها، بس الحزمة المباشرة
/// بتوصل. فيكفي إنه اتجاه واحد يشتغل.
class RoomDiscovery {
  /// عنوان الربط — افتراضياً كل الواجهات، وبيتغيّر لـ loopback بالاختبارات.
  final InternetAddress bindAddress;

  /// لوين منبعت السؤال — افتراضياً بثّ عام، وloopback بالاختبارات.
  final InternetAddress probeTarget;

  /// منفذ الاستماع ومنفذ الأسئلة — شوف [RoomBeacon.announcePort].
  final int listenPort;
  final int probePort;

  RoomDiscovery({
    InternetAddress? bindAddress,
    InternetAddress? probeTarget,
    this.listenPort = roomBeaconPort,
    this.probePort = roomProbePort,
  })  : bindAddress = bindAddress ?? InternetAddress.anyIPv4,
        probeTarget = probeTarget ?? limitedBroadcast;

  final ValueNotifier<List<Room>> rooms = ValueNotifier<List<Room>>([]);

  RawDatagramSocket? _socket;
  Timer? _timer;
  final Map<String, (Room, DateTime)> _seen = {};

  /// بيبدأ الاستماع لبثّ الغرف.
  Future<void> start() async {
    if (_socket != null) return; // شغّال أصلاً — ما منعمل شي.
    await acquireMulticastLock();

    final RawDatagramSocket sock;
    try {
      sock = await RawDatagramSocket.bind(
        bindAddress,
        listenPort,
        reuseAddress: true,
        reusePort: false,
      );
    } catch (_) {
      // ما قدرنا نربط المنفذ — ما منخلّي القفل ماسك الواي فاي بلا داعي.
      await releaseMulticastLock();
      rethrow;
    }
    sock.broadcastEnabled = true;
    _socket = sock;

    sock.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final dg = sock.receive();
        if (dg == null) return;
        handlePacket(dg.address, dg.data);
      },
      // مقبس UDP بيرمي أخطاء غير متزامنة (واجهة اختفت، أو بثّ ما إله طريق
      // — مثلاً واي فاي انقطع بنص اللعبة). بدون هالمعالج الخطأ بيطلع للمنطقة
      // وبيوقّف البحث؛ منسجّله ومنكمّل، الحزمة الجاي بتحاول من جديد.
      onError: (_) {},
      cancelOnError: false,
    );

    unawaited(_probe());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _publish();
      unawaited(_probe());
    });
  }

  /// *وين الغرف؟* — حزمة صغيرة للمضيفين. منبعتها بالبثّ العام وبالبثّ
  /// الموجّه لكل واجهة، والجواب بيرجع مباشرة فما بيتأثر بفلترة البثّ.
  Future<void> _probe() async {
    final sock = _socket;
    if (sock == null) return;
    final payload = utf8.encode(jsonEncode({'probe': 1, 'version': 1}));
    final targets = <InternetAddress>{
      probeTarget,
      if (!probeTarget.isLoopback) ...await directedBroadcasts(),
    };
    // stop() ممكن يكون سبقنا ونحنا عم نجمع العناوين — المقبس سكّر.
    if (!identical(_socket, sock)) return;
    for (final address in targets) {
      try {
        sock.send(payload, address, probePort);
      } on SocketException {
        // ما في شبكة مؤقتاً — منسأل تاني بالثانية الجاي.
      }
    }
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
      // حزمة المنارة أصغر من ٢٠٠ بايت — أكبر من هيك مش منّا.
      if (data.length > 512) return;
      final j = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
      // سؤال لاعب تاني وصلنا بالغلط — مش إعلان غرفة.
      if (j['probe'] != null) return;
      final port = j['port'] as int;
      if (port <= 0 || port > 65535) return;
      // اسم الغرفة بينعرض بلستة اللاعب — منقصّه حتى ما تخرب الشاشة حزمة غريبة.
      var name = (j['room'] as String).trim();
      if (name.isEmpty) return;
      if (name.length > 40) name = name.substring(0, 40);
      final room = Room(name, from, port);
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
