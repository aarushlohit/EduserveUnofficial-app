import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

Future<Uint8List> downloadPdfBytes(
  String url, {
  Map<String, String>? headers,
}) async {
  final uri = Uri.parse(url);
  final client = HttpClient()..badCertificateCallback = (_, __, ___) => true;

  try {
    final request = await client.getUrl(uri);
    headers?.forEach(request.headers.add);
    final response = await request.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'HTTP ${response.statusCode}: Unable to download PDF',
        uri: uri,
      );
    }

    return consolidateHttpClientResponseBytes(response);
  } finally {
    client.close(force: true);
  }
}
