import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/network/messages.dart';
import 'package:meen_al_atlasy/game/models.dart';
import '../game/fixtures.dart';

void main() {
  group('ClientMessage', () {
    test('JoinMessage round-trips through JSON', () {
      final original = JoinMessage(
        playerName: 'لاعب جديد',
        teamId: null,
      );
      final json = original.toJson();
      final decoded = ClientMessage.fromJson(json) as JoinMessage;
      expect(decoded, isA<JoinMessage>());
      expect(decoded.playerName, equals('لاعب جديد'));
      expect(decoded.teamId, isNull);
    });

    test('JoinMessage with teamId round-trips', () {
      final original = JoinMessage(
        playerName: 'لاعب١',
        teamId: TeamId.team1,
      );
      final json = original.toJson();
      final decoded = ClientMessage.fromJson(json);
      expect(decoded, isA<JoinMessage>());
      expect((decoded as JoinMessage).teamId, equals(TeamId.team1));
    });

    test('ChangeTeamMessage round-trips through JSON', () {
      final original = ChangeTeamMessage(
        playerId: 'player1',
        teamId: TeamId.team2,
      );
      final json = original.toJson();
      final decoded = ClientMessage.fromJson(json);
      expect(decoded, isA<ChangeTeamMessage>());
      final msg = decoded as ChangeTeamMessage;
      expect(msg.playerId, equals('player1'));
      expect(msg.teamId, equals(TeamId.team2));
    });

    test('BuzzMessage round-trips through JSON', () {
      final original = BuzzMessage(
        playerId: 'player42',
        atMillis: 1234567890,
      );
      final json = original.toJson();
      final decoded = ClientMessage.fromJson(json);
      expect(decoded, isA<BuzzMessage>());
      final msg = decoded as BuzzMessage;
      expect(msg.playerId, equals('player42'));
      expect(msg.atMillis, equals(1234567890));
    });

    test('ChooseMessage round-trips through JSON', () {
      final original = ChooseMessage(
        playerId: 'player5',
        play: true,
      );
      final json = original.toJson();
      final decoded = ClientMessage.fromJson(json);
      expect(decoded, isA<ChooseMessage>());
      final msg = decoded as ChooseMessage;
      expect(msg.playerId, equals('player5'));
      expect(msg.play, equals(true));
    });

    test('ChooseMessage with play: false round-trips', () {
      final original = ChooseMessage(
        playerId: 'player3',
        play: false,
      );
      final json = original.toJson();
      final decoded = ClientMessage.fromJson(json);
      final msg = decoded as ChooseMessage;
      expect(msg.play, equals(false));
    });

    test('unknown type throws FormatException', () {
      final json = {'type': 'unknown_type'};
      expect(() => ClientMessage.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('missing required field throws FormatException', () {
      final json = {'type': 'join'}; // missing playerName
      expect(() => ClientMessage.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('ignores unknown extra keys', () {
      final json = {
        'type': 'join',
        'playerName': 'test',
        'teamId': null,
        'extraKey': 'should be ignored',
        'anotherExtra': 123,
      };
      final decoded = ClientMessage.fromJson(json);
      expect(decoded, isA<JoinMessage>());
    });
  });

  group('HostMessage', () {
    test('StateUpdate round-trips through JSON', () {
      final state = freshState();
      final original = StateUpdate(state: state);
      final json = original.toJson();
      final decoded = HostMessage.fromJson(json);
      expect(decoded, isA<StateUpdate>());
      final msg = decoded as StateUpdate;
      expect(msg.state, equals(state));
    });

    test('StateUpdate with maskedForPlayers round-trips', () {
      final state = freshState().maskedForPlayers();
      final original = StateUpdate(state: state);
      final json = original.toJson();
      final decoded = HostMessage.fromJson(json);
      expect(decoded, isA<StateUpdate>());
      final msg = decoded as StateUpdate;
      expect(msg.state, equals(state));
    });

    test('Assigned round-trips through JSON', () {
      final original = Assigned(
        playerId: 'player99',
        teamId: TeamId.team1,
      );
      final json = original.toJson();
      final decoded = HostMessage.fromJson(json);
      expect(decoded, isA<Assigned>());
      final msg = decoded as Assigned;
      expect(msg.playerId, equals('player99'));
      expect(msg.teamId, equals(TeamId.team1));
    });

    test('unknown type throws FormatException', () {
      final json = {'type': 'bad_type'};
      expect(() => HostMessage.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('missing required field throws FormatException', () {
      final json = {'type': 'assigned', 'playerId': 'p1'}; // missing teamId
      expect(() => HostMessage.fromJson(json), throwsA(isA<FormatException>()));
    });
  });

  group('encode/decode functions', () {
    test('encodeClientMessage and decodeClientMessage round-trip', () {
      final original = JoinMessage(playerName: 'Test', teamId: TeamId.team2);
      final encoded = encodeClientMessage(original).codeUnits;
      final decoded = decodeClientMessage(encoded) as JoinMessage;
      expect(decoded, isA<JoinMessage>());
      expect(decoded.playerName, equals('Test'));
      expect(decoded.teamId, equals(TeamId.team2));
    });

    test('encodeHostMessage and decodeHostMessage round-trip', () {
      final original = Assigned(playerId: 'p7', teamId: TeamId.team1);
      final encoded = encodeHostMessage(original).codeUnits;
      final decoded = decodeHostMessage(encoded);
      expect(decoded, isA<Assigned>());
      expect((decoded as Assigned).playerId, equals('p7'));
    });

    test('decodeClientMessage throws on unknown type', () {
      final encoded = '{"type":"invalid"}'.codeUnits;
      expect(() => decodeClientMessage(encoded), throwsA(isA<FormatException>()));
    });

    test('decodeHostMessage throws on unknown type', () {
      final encoded = '{"type":"bad"}'.codeUnits;
      expect(() => decodeHostMessage(encoded), throwsA(isA<FormatException>()));
    });
  });
}
