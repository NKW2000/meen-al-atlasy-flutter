import 'package:flutter_test/flutter_test.dart';
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
}
