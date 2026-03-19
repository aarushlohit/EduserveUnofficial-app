import 'dart:typed_data';

import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/network/pdf_downloader.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class CommonPdfViewerPage extends StatefulWidget {
  const CommonPdfViewerPage({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<CommonPdfViewerPage> createState() => _CommonPdfViewerPageState();
}

class _CommonPdfViewerPageState extends State<CommonPdfViewerPage> {
  String? _error;
  late Future<Uint8List> _pdfFuture;

  @override
  void initState() {
    super.initState();
    _pdfFuture = _loadPdfBytes();
  }

  Future<Uint8List> _loadPdfBytes() async {
    return downloadPdfBytes(
      widget.url,
      headers: <String, String>{
        'User-Agent': AppConfig.desktopUserAgent,
        'Accept': 'application/pdf,*/*',
      },
    );
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      return;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            _error = snapshot.error?.toString() ?? _error ?? 'Unknown error';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Unable to open PDF inside app.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _openInBrowser,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open in browser'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SfPdfViewer.memory(
            snapshot.data!,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            onDocumentLoadFailed: (details) {
              if (!mounted) {
                return;
              }
              setState(() {
                _error = details.description;
              });
            },
          );
        },
      ),
    );
  }
}
