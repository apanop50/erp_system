/// Pdf Font loader with platform-conditional implementation.
///
/// On desktop & mobile (`dart:io`) an Arabic font is downloaded and cached.
/// On web a stub returns `null` and callers fall back to the default font.
import 'dart:typed_data';

import 'pdf_font_stub.dart'
    if (dart.library.io) 'pdf_font_io.dart' as impl;

/// Loads Arabic PDF font bytes (nullable).
Future<Uint8List?> loadArabicPdfFontBytes() =>
    impl.loadArabicPdfFontBytes();