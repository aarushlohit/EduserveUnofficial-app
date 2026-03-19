import 'dart:typed_data';

import 'pdf_downloader_stub.dart' if (dart.library.io) 'pdf_downloader_io.dart'
    as impl;

Future<Uint8List> downloadPdfBytes(
  String url, {
  Map<String, String>? headers,
}) {
  return impl.downloadPdfBytes(url, headers: headers);
}
