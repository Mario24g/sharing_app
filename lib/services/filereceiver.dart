import 'dart:convert';
import 'dart:io';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

class FileReceiver {
  final int port;
  final void Function(String message)? onFileReceived;

  final Map<String, int> _expectedFiles = {};
  final Map<String, int> _receivedFiles = {};

  FileReceiver({required this.port, required this.onFileReceived});

  void startReceiverServer() async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print('Server running on http://${server.address.address}:${server.port}');

    await for (HttpRequest request in server) {
      if (request.method == 'POST' && request.uri.path == '/upload-metadata') {
        await _handleMetadata(request);
      } else if (request.method == 'POST' && request.uri.path == '/upload') {
        await _handleFileUpload(request);
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found')
          ..close();
      }
    }
  }

  Future _handleMetadata(HttpRequest request) async {
    final String content = await utf8.decoder.bind(request).join();
    final dynamic data = jsonDecode(content);
    final String ip =
        request.connectionInfo?.remoteAddress.address ?? 'unknown';

    final int expected = data['fileCount'] ?? 1;
    _expectedFiles[ip] = expected;
    _receivedFiles[ip] = 0;

    request.response
      ..statusCode = HttpStatus.ok
      ..write('Metadata received')
      ..close();
  }

  Future _handleFileUpload(HttpRequest request) async {
    final ip = request.connectionInfo?.remoteAddress.address ?? 'unknown';

    try {
      // Parse and save file as you do currently
      final contentType = request.headers.contentType;
      if (contentType == null ||
          !contentType.mimeType.startsWith('multipart/form-data')) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Invalid content type')
          ..close();
        return;
      }

      final boundary = contentType.parameters['boundary']!;
      final parts =
          await MimeMultipartTransformer(boundary).bind(request).toList();

      for (final part in parts) {
        final headers = part.headers;
        final match = RegExp(
          r'filename="(.+)"',
        ).firstMatch(headers['content-disposition'] ?? '');
        final filename = match?.group(1) ?? 'received_file';

        final tempDir = await getTemporaryDirectory();
        final tempFilePath =
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$filename';
        final file = File(tempFilePath);
        await file.writeAsBytes(
          await part.toList().then((parts) => parts.expand((e) => e).toList()),
        );

        final bool? success = await copyFileIntoDownloadFolder(
          tempFilePath,
          filename,
        );
        if (!success!) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Failed to save file')
            ..close();
          return;
        }

        // Update received count
        _receivedFiles[ip] = (_receivedFiles[ip] ?? 0) + 1;
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..write('File(s) uploaded successfully')
        ..close();

      // Notify only if all expected files are received
      if (_receivedFiles[ip] == _expectedFiles[ip]) {
        onFileReceived?.call("${_receivedFiles[ip]} file(s) received from $ip");
        _expectedFiles.remove(ip);
        _receivedFiles.remove(ip);
      }
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Error: $e')
        ..close();
      onFileReceived?.call("Error receiving file from $ip");
    }
  }
}
