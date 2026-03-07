import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

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
      // print('Error loading network logo: $e');
      return null;
    }
  } else {
    // Local File
    final file = File(path);
    if (file.existsSync()) {
      try {
        return file.readAsBytesSync();
      } catch (_) {
        return null;
      }
    }
  }
  return null;
}
