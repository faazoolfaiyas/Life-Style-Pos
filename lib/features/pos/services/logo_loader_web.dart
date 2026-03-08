import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

Future<Uint8List?> loadLogo(String path) async {
  if (path.isEmpty) return null;

  // Check for URL
  if (path.startsWith('http://') || path.startsWith('https://')) {
    try {
      final response = await http.get(Uri.parse(path));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      return null;
    }
  } else {
    // For Web, if it's the default local path or the filename, load from assets
    if (path.contains('lifestyle_logo_black.png')) {
      try {
        final byteData = await rootBundle.load('lifestyle_logo_black.png');
        return byteData.buffer.asUint8List();
      } catch (e) {
        return null;
      }
    }
  }
  
  return null;
}
