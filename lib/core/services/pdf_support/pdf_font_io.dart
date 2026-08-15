/// Pdf Font IO (Desktop & Mobile)
///
/// Loads an Arabic-capable TTF font (Cairo from Google Fonts) for PDF
/// generation. The font is downloaded once and cached in the app's
/// temporary directory so subsequent runs work offline.
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Candidate TTF URLs (first reachable one is used and cached).
const List<String> _fontUrls = [
  // Cairo variable TTF from google/fonts GitHub (mirrored by jsDelivr).
  'https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/cairo/Cairo%5Bslnt%2Cwght%5D.ttf',
  // Direct GitHub raw alternative.
  'https://raw.githubusercontent.com/google/fonts/main/ofl/cairo/Cairo%5Bslnt%2Cwght%5D.ttf',
];
const String _fontFileName = 'cairo_arabic.font';

/// Returns the Arabic PDF font bytes, or `null` if the download fails.
Future<Uint8List?> loadArabicPdfFontBytes() async {
  try {
    // Try to reuse a cached copy first.
    final dir = await getTemporaryDirectory();
    final cached = File('${dir.path}${Platform.pathSeparator}$_fontFileName');
    if (cached.existsSync()) {
      return cached.readAsBytesSync();
    }

    // Download the font from the first reachable candidate.
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      for (final url in _fontUrls) {
        try {
          final request = await client.getUrl(Uri.parse(url));
          final response = await request.close();
          if (response.statusCode != 200) {
            await response.drain<void>();
            continue;
          }
          final bytes = await response.fold<BytesBuilder>(
            BytesBuilder(copy: false),
            (builder, chunk) => builder..add(chunk),
          );
          final data = bytes.takeBytes();
          // Cache for offline reuse.
          try {
            await cached.writeAsBytes(data, flush: true);
          } catch (_) {}
          return data;
        } catch (_) {
          continue;
        }
      }
      return null;
    } finally {
      client.close(force: true);
    }
  } catch (_) {
    return null;
  }
}