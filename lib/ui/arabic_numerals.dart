/// الأرقام بتنعرض بالشكل العربي (٠١٢٣) زي التصميم.
///
/// منفّذ عن `ArabicNumerals.kt` بالمشروع الأصلي (Kotlin).
library;

const List<String> _arabicDigits = [
  '٠',
  '١',
  '٢',
  '٣',
  '٤',
  '٥',
  '٦',
  '٧',
  '٨',
  '٩',
];

extension ArabicInt on int {
  String ar() => toString().arDigits();
}

extension ArabicString on String {
  String arDigits() => split('').map((char) {
        final code = char.codeUnitAt(0);
        if (code >= 0x30 && code <= 0x39) {
          return _arabicDigits[code - 0x30];
        }
        return char;
      }).join();
}
