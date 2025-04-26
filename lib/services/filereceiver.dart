import 'dart:async';
import 'dart:io';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

class FileReceiver {
  HttpServer? _server;
  int _bytesReceived = 0;
  final int port;

  FileReceiver({required this.port});

  void startReceiverServer() async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
    );
    print('Server running on http://${server.address.address}:${server.port}');

    await for (HttpRequest request in server) {
      if (request.method == 'POST' && request.uri.path == '/upload') {
        try {
          final ContentType? contentType = request.headers.contentType;
          if (contentType == null ||
              !contentType.mimeType.startsWith('multipart/form-data')) {
            request.response
              ..statusCode = HttpStatus.badRequest
              ..write('Invalid content type');
            await request.response.close();
            continue;
          }

          // Parse the multipart request
          final String? boundary = contentType.parameters['boundary'];
          final MimeMultipartTransformer transformer = MimeMultipartTransformer(
            boundary!,
          );
          final List<MimeMultipart> parts =
              await transformer.bind(request).toList();

          for (final MimeMultipart part in parts) {
            final Map<String, String> headers = part.headers;
            final String? contentDisposition = headers['content-disposition'];

            // Extract filename
            final RegExp filenameRegex = RegExp(r'filename="(.+)"');
            final RegExpMatch? match = filenameRegex.firstMatch(
              contentDisposition!,
            );
            final String filename =
                match != null ? match.group(1)! : 'received_file';

            // Create a temp file
            final Directory tempDir = await getTemporaryDirectory();
            final String tempFilePath = '${tempDir.path}/$filename';
            final File tempFile = File(tempFilePath);
            await tempFile.writeAsBytes(
              await part.toList().then(
                (parts) => parts.expand((e) => e).toList(),
              ),
            );

            // Move to Downloads
            final bool? success = await copyFileIntoDownloadFolder(
              tempFilePath,
              filename,
            );
            if (success == true) {
              print('File saved as $filename in Downloads');
              request.response
                ..statusCode = HttpStatus.ok
                ..write('Upload received and saved as $filename');
            } else {
              print('Failed to move file to Downloads');
              request.response
                ..statusCode = HttpStatus.internalServerError
                ..write('Failed to save file');
            }
          }
        } catch (e) {
          print('Error receiving file: $e');
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Error: $e');
        }
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
      }

      await request.response.close();
    }
  }

  Future<void> startServer() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 8889);
    print('File receiver server started on port 8889');

    await for (HttpRequest request in _server!) {
      if (request.method == 'POST' && request.uri.path == '/upload') {
        try {
          final contentLength = request.contentLength;
          _bytesReceived = 0;
          print('Starting file transfer ($contentLength bytes)');

          final file = await _saveFileWithProgress(request, contentLength);

          print('\nFile transfer complete: ${file.path}');
          request.response
            ..statusCode = HttpStatus.ok
            ..write('File received successfully');
        } catch (e) {
          print('\nFile transfer error: $e');
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Error: $e');
        } finally {
          await request.response.close();
        }
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
        await request.response.close();
      }
    }
  }

  Future<File> _saveFileWithProgress(
    HttpRequest request,
    int contentLength,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/received_${DateTime.now().millisecondsSinceEpoch}',
    );
    final sink = file.openWrite();

    await request.listen((List<int> chunk) {
      _bytesReceived += chunk.length;
      final progress = (_bytesReceived / contentLength * 100).toStringAsFixed(
        1,
      );
      print('Progress: $progress% ($_bytesReceived/$contentLength bytes)\r');
    }).asFuture();

    await sink.close();
    return file;
  }

  Future<void> stopServer() async {
    await _server?.close();
    print('File receiver server stopped');
  }
}

/*
class FileReceiver {
  HttpServer? _server;

  Future<void> startServer() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 8889);
    print('✅ Server running on port 8889');

    await for (HttpRequest request in _server!) {
      if (request.method == 'POST' && request.uri.path == '/upload') {
        try {
          final contentType = request.headers.contentType;
          if (contentType == null ||
              !contentType.mimeType.startsWith('multipart/form-data')) {
            request.response
              ..statusCode = HttpStatus.badRequest
              ..write('Invalid content type');
            await request.response.close();
            continue;
          }

          final boundary = contentType.parameters['boundary'];
          if (boundary == null) {
            request.response
              ..statusCode = HttpStatus.badRequest
              ..write('Missing boundary');
            await request.response.close();
            continue;
          }

          final transformer = MimeMultipartTransformer(boundary);
          final parts = await transformer.bind(request).toList();

          for (final part in parts) {
            final contentDisp = part.headers['content-disposition'];
            final match = RegExp(
              r'filename="(.+)"',
            ).firstMatch(contentDisp ?? '');
            final filename = match != null ? match.group(1)! : 'received_file';

            final tempDir = await getTemporaryDirectory();
            final tempFilePath = '${tempDir.path}/$filename';
            final file = File(tempFilePath);
            final sink = file.openWrite();

            int bytesReceived = 0;
            final contentLength = int.tryParse(
              part.headers['content-length'] ?? '0',
            );

            final completer = Completer<void>();
            part.listen(
              (chunk) {
                bytesReceived += chunk.length as int;
                sink.add(chunk);

                if (contentLength != null && contentLength > 0) {
                  final progress = (bytesReceived / contentLength * 100)
                      .toStringAsFixed(1);
                  print(
                    'Progress: $progress% ($bytesReceived / $contentLength bytes)',
                  );
                } else {
                  print('Received $bytesReceived bytes...');
                }
              },
              onDone: () => completer.complete(),
              onError: (e) => completer.completeError(e),
              cancelOnError: true,
            );

            await completer.future;
            await sink.close();

            final success = await _moveToDownloads(tempFilePath, filename);
            if (success) {
              print('✅ File saved to Downloads: $filename');
              request.response
                ..statusCode = HttpStatus.ok
                ..write('Upload received and saved as $filename');
            } else {
              print('❌ Failed to move file to Downloads');
              request.response
                ..statusCode = HttpStatus.internalServerError
                ..write('Upload received but failed to save');
            }
          }
        } catch (e) {
          print('❌ Error: $e');
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Error: $e');
        } finally {
          await request.response.close();
        }
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not Found');
        await request.response.close();
      }
    }
  }

  Future<bool> _moveToDownloads(String sourcePath, String filename) async {
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) return false;

      String destPath = '${downloadsDir.path}/$filename';

      // Avoid filename conflicts
      int counter = 1;
      while (await File(destPath).exists()) {
        final base =
            filename.contains('.')
                ? filename.substring(0, filename.lastIndexOf('.'))
                : filename;
        final ext =
            filename.contains('.')
                ? filename.substring(filename.lastIndexOf('.'))
                : '';
        destPath = '${downloadsDir.path}/${base}_$counter$ext';
        counter++;
      }

      await File(sourcePath).copy(destPath);
      await File(sourcePath).delete();
      return true;
    } catch (e) {
      print('Moving file failed: $e');
      return false;
    }
  }

  Future<void> stopServer() async {
    await _server?.close();
    print('Server stopped');
  }
}

*/
