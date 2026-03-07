import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GithubStorageService {
  final String _username = 'lifestylekky';
  final String _repo = 'image-store';
  final String _token = 'YOUR_GITHUB_TOKEN'; // TODO: Move to secure storage or environment variable
  final String _branch = 'main'; // Adjust if using 'master'

  Future<String> uploadFile(String filename, Uint8List fileBytes) async {
    final path = 'products/${DateTime.now().millisecondsSinceEpoch}_$filename';
    final url = Uri.parse('https://api.github.com/repos/$_username/$_repo/contents/$path');
    final content = base64Encode(fileBytes);

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/vnd.github.v3+json',
        },
        body: jsonEncode({
          'message': 'Upload $filename',
          'content': content,
          'branch': _branch,
        }),
      );

      if (response.statusCode == 201) {
        final dateMap = jsonDecode(response.body);
        // Using jsdelivr for CDN access or raw.githubusercontent
        // raw: https://raw.githubusercontent.com/username/repo/branch/path
        return 'https://raw.githubusercontent.com/$_username/$_repo/$_branch/$path';
      } else {
        throw Exception('Failed to upload image: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading to GitHub: $e');
    }
  }
  Future<String> uploadBillLogo(String filename, Uint8List fileBytes) async {
    // dedicated folder for bill logos
    final path = 'bill_logo/${DateTime.now().millisecondsSinceEpoch}_$filename';
    final url = Uri.parse('https://api.github.com/repos/$_username/$_repo/contents/$path');
    final content = base64Encode(fileBytes);

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/vnd.github.v3+json',
        },
        body: jsonEncode({
          'message': 'Upload Bill Logo $filename',
          'content': content,
          'branch': _branch,
        }),
      );

      if (response.statusCode == 201) {
        // Using raw.githubusercontent for direct access
        return 'https://raw.githubusercontent.com/$_username/$_repo/$_branch/$path';
      } else {
        throw Exception('Failed to upload logo: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading logo to GitHub: $e');
    }
  }
}
