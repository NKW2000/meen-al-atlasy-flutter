/// لستة الغرف بدون مقابس: نفس الغرفة اللي بيوصل بثّها من أكتر من عنوان
/// (واي فاي + نقطة اتصال، أو بثّ عام + موجّه) لازم تطلع مرة وحدة.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/network/room_discovery.dart';

List<int> _packet({required String room, required int port, String? id}) =>
    utf8.encode(jsonEncode({'room': room, 'port': port, 'version': 1, 'id': ?id}));

void main() {
  test('the same session id from two source addresses is one room', () {
    final discovery = RoomDiscovery();
    discovery.handlePacket(
      InternetAddress('192.168.43.1'),
      _packet(room: 'غرفة العيلة', port: 47215, id: 'abc'),
    );
    discovery.handlePacket(
      InternetAddress('10.0.0.5'),
      _packet(room: 'غرفة العيلة', port: 47215, id: 'abc'),
    );

    expect(discovery.rooms.value, hasLength(1));
    // آخر عنوان شفناه — هو اللي بيوصل (نفس الشبكة اللي وصلنا منها الحزمة).
    expect(discovery.rooms.value.single.host.address, '10.0.0.5');
    expect(discovery.rooms.value.single.name, 'غرفة العيلة');
  });

  test('a host that restarts with a new session id replaces its old entry by address',
      () {
    final discovery = RoomDiscovery();
    final host = InternetAddress('192.168.43.1');
    discovery.handlePacket(host, _packet(room: 'غرفة', port: 47215, id: 'old'));
    discovery.handlePacket(host, _packet(room: 'غرفة', port: 47215, id: 'new'));

    expect(discovery.rooms.value, hasLength(1));
  });

  test('two different hosts stay two rooms, and legacy packets without an id still work',
      () {
    final discovery = RoomDiscovery();
    discovery.handlePacket(InternetAddress('192.168.1.2'), _packet(room: 'أ', port: 47215, id: 'x'));
    discovery.handlePacket(InternetAddress('192.168.1.3'), _packet(room: 'ب', port: 47215, id: 'y'));
    discovery.handlePacket(InternetAddress('192.168.1.4'), _packet(room: 'ج', port: 47215));

    expect(discovery.rooms.value.map((r) => r.name), ['أ', 'ب', 'ج']);
  });

  test('a malformed packet is ignored', () {
    final discovery = RoomDiscovery();
    discovery.handlePacket(InternetAddress('192.168.1.2'), utf8.encode('not json'));
    expect(discovery.rooms.value, isEmpty);
  });
}
