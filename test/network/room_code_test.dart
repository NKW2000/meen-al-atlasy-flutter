import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/network/room_code.dart';

void main() {
  group('Arabic digits', () {
    // الكود بيبيّن عند المضيف بأرقام عربية (١١٠٠٩)، والكيبورد العربي بيكتبها
    // هيك — كانت تنرفض وما يقدر اللاعب يفوت بالكود أبداً.
    test('a code typed with Arabic-Indic digits decodes like ASCII', () {
      final mine = InternetAddress('192.168.1.7');
      expect(decodeRoomCode('١١٠٠٩', mine), decodeRoomCode('11009', mine));
      expect(decodeRoomCode('١١٠٠٩', mine)?.address, '192.168.43.1');
    });

    test('Persian digits and surrounding spaces are fine too', () {
      final mine = InternetAddress('192.168.1.7');
      expect(decodeRoomCode(' ۱۱۰۰۹ ', mine)?.address, '192.168.43.1');
    });

    test('asciiDigits maps every digit and leaves the rest alone', () {
      expect(asciiDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(asciiDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
      expect(asciiDigits('ab 12 ٣'), 'ab 12 3');
    });
  });

  group('encodeRoomCode', () {
    test('192.168.43.1 encodes to 11009', () {
      final ip = InternetAddress('192.168.43.1');
      final code = encodeRoomCode(ip);
      expect(code, equals('11009'));
    });

    test('192.168.0.1 encodes to 00001', () {
      final ip = InternetAddress('192.168.0.1');
      final code = encodeRoomCode(ip);
      expect(code, equals('00001'));
    });

    test('192.168.255.255 encodes to 65535', () {
      final ip = InternetAddress('192.168.255.255');
      final code = encodeRoomCode(ip);
      expect(code, equals('65535'));
    });

    test('192.168.0.0 encodes to 00000', () {
      final ip = InternetAddress('192.168.0.0');
      final code = encodeRoomCode(ip);
      expect(code, equals('00000'));
    });

    test('IPv6 address throws ArgumentError', () {
      final ipv6 = InternetAddress('::1');
      expect(() => encodeRoomCode(ipv6), throwsA(isA<ArgumentError>()));
    });
  });

  group('decodeRoomCode', () {
    test('11009 with player ip 192.168.0.7 decodes to 192.168.43.1', () {
      final playerIp = InternetAddress('192.168.0.7');
      final result = decodeRoomCode('11009', playerIp);
      expect(result, isNotNull);
      expect(result!.host, equals('192.168.43.1'));
    });

    test('00001 with player ip 192.168.1.2 decodes to 192.168.0.1', () {
      final playerIp = InternetAddress('192.168.1.2');
      final result = decodeRoomCode('00001', playerIp);
      expect(result, isNotNull);
      expect(result!.host, equals('192.168.0.1'));
    });

    test('65535 with player ip 10.0.0.5 decodes to 10.0.255.255', () {
      final playerIp = InternetAddress('10.0.0.5');
      final result = decodeRoomCode('65535', playerIp);
      expect(result, isNotNull);
      expect(result!.host, equals('10.0.255.255'));
    });

    test('00000 with player ip 172.16.0.1 decodes to 172.16.0.0', () {
      final playerIp = InternetAddress('172.16.0.1');
      final result = decodeRoomCode('00000', playerIp);
      expect(result, isNotNull);
      expect(result!.host, equals('172.16.0.0'));
    });

    test('abc returns null', () {
      final playerIp = InternetAddress('192.168.1.1');
      final result = decodeRoomCode('abc', playerIp);
      expect(result, isNull);
    });

    test('70000 returns null (exceeds 65535)', () {
      final playerIp = InternetAddress('192.168.1.1');
      final result = decodeRoomCode('70000', playerIp);
      expect(result, isNull);
    });

    test('not 5 digits returns null', () {
      final playerIp = InternetAddress('192.168.1.1');
      expect(decodeRoomCode('123', playerIp), isNull);
      expect(decodeRoomCode('123456', playerIp), isNull);
      expect(decodeRoomCode('', playerIp), isNull);
    });

    test('negative value in code returns null', () {
      final playerIp = InternetAddress('192.168.1.1');
      final result = decodeRoomCode('-0001', playerIp);
      expect(result, isNull);
    });
  });

  group('round-trip', () {
    test('encodeRoomCode and decodeRoomCode round-trip', () {
      final hostIp = InternetAddress('192.168.43.1');
      final code = encodeRoomCode(hostIp);

      // Simulate player with different first two octets
      final playerIp = InternetAddress('10.0.0.5');
      final decoded = decodeRoomCode(code, playerIp);

      expect(decoded, isNotNull);
      expect(decoded!.host, equals('10.0.43.1'));
    });

    test('encodeRoomCode and decodeRoomCode preserve last two octets', () {
      final hostIp = InternetAddress('192.168.123.45');
      final code = encodeRoomCode(hostIp);

      final playerIp = InternetAddress('172.16.0.1');
      final decoded = decodeRoomCode(code, playerIp);

      expect(decoded, isNotNull);
      expect(decoded!.host, equals('172.16.123.45'));
    });
  });
}
