/// Arabic Text Shaping
///
/// Converts Unicode Arabic text into Arabic Presentation Forms so glyphs
/// appear connected inside the `pdf` package. The `pdf` package (with its
/// default `useBidi` and `textDirection: rtl`) handles the visual ordering,
/// so this function performs only the presentation-form substitution
/// (no manual reversal).
library;

/// Maps a base Arabic letter to its contextual presentation forms.
/// Order: isolated, initial, medial, final.
///
/// Important: keep these as code points, not strings like `\\uFE8D`.
/// A previous implementation used escaped strings and indexed into the literal
/// backslash text, which made PDF output show wrong/empty glyphs.
const Map<String, List<int>> _forms = {
  'ا': [0xFE8D, 0xFE8D, 0xFE8E, 0xFE8E], // Alef
  'ب': [0xFE8F, 0xFE91, 0xFE92, 0xFE8E], // Beh
  'ت': [0xFE95, 0xFE97, 0xFE98, 0xFE94], // Teh
  'ث': [0xFE99, 0xFE9B, 0xFE9C, 0xFE9A], // Theh
  'ج': [0xFE9D, 0xFE9F, 0xFEA0, 0xFE9E], // Jeem
  'ح': [0xFEA1, 0xFEA3, 0xFEA4, 0xFEA2], // Hah
  'خ': [0xFEA5, 0xFEA7, 0xFEA8, 0xFEA6], // Khah
  'د': [0xFEA9, 0xFEA9, 0xFEAA, 0xFEAA], // Dal
  'ذ': [0xFEAB, 0xFEAB, 0xFEAC, 0xFEAC], // Thal
  'ر': [0xFEAD, 0xFEAD, 0xFEAE, 0xFEAE], // Reh
  'ز': [0xFEAF, 0xFEAF, 0xFEB0, 0xFEB0], // Zain
  'س': [0xFEB1, 0xFEB3, 0xFEB4, 0xFEB2], // Seen
  'ش': [0xFEB5, 0xFEB7, 0xFEB8, 0xFEB6], // Sheen
  'ص': [0xFEB9, 0xFEBB, 0xFEBC, 0xFEBA], // Sad
  'ض': [0xFEBD, 0xFEBF, 0xFEC0, 0xFEBE], // Dad
  'ط': [0xFEC1, 0xFEC3, 0xFEC4, 0xFEC2], // Tah
  'ظ': [0xFEC5, 0xFEC7, 0xFEC8, 0xFEC6], // Zah
  'ع': [0xFEC9, 0xFECB, 0xFECC, 0xFECA], // Ain
  'غ': [0xFECD, 0xFECF, 0xFED0, 0xFECE], // Ghain
  'ف': [0xFED1, 0xFED3, 0xFED4, 0xFED2], // Feh
  'ق': [0xFED5, 0xFED7, 0xFED8, 0xFED6], // Qaf
  'ك': [0xFED9, 0xFEDB, 0xFEDC, 0xFEDA], // Kaf
  'ل': [0xFEDD, 0xFEDF, 0xFEE0, 0xFEDE], // Lam
  'م': [0xFEE1, 0xFEE3, 0xFEE4, 0xFEE2], // Meem
  'ن': [0xFEE5, 0xFEE7, 0xFEE8, 0xFEE6], // Noon
  'ه': [0xFEE9, 0xFEEB, 0xFEEC, 0xFEEA], // Heh
  'و': [0xFEED, 0xFEED, 0xFEEE, 0xFEEE], // Waw
  'ي': [0xFEF1, 0xFEF3, 0xFEF4, 0xFEF2], // Yeh
  'آ': [0xFE81, 0xFE81, 0xFE82, 0xFE82], // Alef Mada
  'أ': [0xFE83, 0xFE83, 0xFE84, 0xFE84], // Alef Hamza above
  'ؤ': [0xFE85, 0xFE85, 0xFE86, 0xFE86], // Waw Hamza
  'ئ': [0xFE87, 0xFE87, 0xFE88, 0xFE88], // Yeh Hamza
  'ى': [0xFEEF, 0xFEEF, 0xFEF0, 0xFEF0], // Alef maksura
  'ة': [0xFE93, 0xFE93, 0xFE94, 0xFE94], // Teh marbuta
};

/// Letters that do not connect to the following letter.
const String _nonConnecting = 'ادرزوآأؤىة';

/// Returns true if [ch] is an Arabic base letter.
bool _isArabicBase(String ch) => _forms.containsKey(ch);

/// Returns the presentation form for [ch] at position [index] of [text].
String _formAt(String ch, String text, int index) {
  final forms = _forms[ch]!;
  final hasPrev = index > 0 && _isArabicBase(text[index - 1]);
  final hasNext = index < text.length - 1 && _isArabicBase(text[index + 1]);

  // Whether the previous letter connects to this one.
  final prevConnects = hasPrev && !_nonConnecting.contains(text[index - 1]);
  // Whether this letter connects to the next one.
  final nextConnects = hasNext && !_nonConnecting.contains(ch);

  if (prevConnects && nextConnects) {
    return String.fromCharCode(forms[2]); // medial
  }
  if (prevConnects && !nextConnects) {
    return String.fromCharCode(forms[3]); // final
  }
  if (!prevConnects && nextConnects) {
    return String.fromCharCode(forms[1]); // initial
  }
  return String.fromCharCode(forms[0]); // isolated
}

/// Converts [input] Arabic text to presentation forms (for use with the
/// `pdf` package, whose bidi handler orders the text when
/// `textDirection: rtl`). Non-Arabic characters are passed through.
String shapingArabic(String input) {
  if (input.isEmpty) return '';
  final sb = StringBuffer();
  for (int i = 0; i < input.length; i++) {
    final ch = input[i];
    sb.write(_isArabicBase(ch) ? _formAt(ch, input, i) : ch);
  }
  return sb.toString();
}

/// Helper to build a shaped Arabic string for a paragraph.
String arText(String input) => shapingArabic(input);
