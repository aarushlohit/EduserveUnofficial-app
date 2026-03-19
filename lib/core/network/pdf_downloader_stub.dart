import 'dart:typed_data';

import 'package:http/http.dart' as http;

Future<Uint8List> downloadPdfBytes(
  String url, {
  Map<String, String>? headers,
}) async {
  final uri = Uri.parse(url);
  final response = await http.get(uri, headers: headers);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return response.bodyBytes;
  }

  throw Exception('HTTP ${response.statusCode}: Unable to download PDF');
}
