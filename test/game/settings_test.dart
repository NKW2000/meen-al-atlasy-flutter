import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/game/settings.dart';

void main() {
  test('multipliers stretch to cover every round', () {
    final settings = GameSettings(rounds: 6, multipliers: [1, 2, 3]);

    // آخر مضاعف بينكرر لباقي الجولات.
    expect(settings.multipliersForRounds(), [1, 2, 3, 3, 3, 3]);
  });

  test('multipliers are trimmed when there are fewer rounds', () {
    final settings = GameSettings(rounds: 2, multipliers: [1, 1, 2, 3]);

    expect(settings.multipliersForRounds(), [1, 1]);
  });

  test('the game needs one question per round', () {
    expect(GameSettings(rounds: 4).questionsNeeded(), 4);
    expect(GameSettings(rounds: 7).questionsNeeded(), 7);
  });

  test('sixteen rounds are allowed and every round gets a multiplier', () {
    final settings = GameSettings(rounds: 16).clamped();

    expect(settings.rounds, 16);
    expect(settings.questionsNeeded(), 16);
    expect(settings.multipliersForRounds().length, 16);
  });

  test('out of range values are pulled back into range', () {
    final settings = GameSettings(rounds: 99, strikesToSteal: 0).clamped();

    expect(settings.rounds, GameSettings.maxRounds);
    expect(settings.strikesToSteal, GameSettings.minStrikes);
  });

  test("an empty multiplier list falls back to the show's defaults", () {
    expect(
      GameSettings(multipliers: const []).clamped().multipliers,
      GameSettings.defaultMultipliers,
    );
  });

  test('two independently constructed identical settings are equal', () {
    final a = GameSettings(
      rounds: 5,
      multipliers: const [1, 2, 3],
      roomName: 'غرفتي',
      teamNames: const {TeamId.team1: 'أ', TeamId.team2: 'ب'},
    );
    final b = GameSettings(
      rounds: 5,
      multipliers: const [1, 2, 3],
      roomName: 'غرفتي',
      teamNames: const {TeamId.team1: 'أ', TeamId.team2: 'ب'},
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(b.copyWith(rounds: 6)));
  });
}
