import 'dart:io';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

class FileReceiver {
  final int port;
  final void Function(String message)? onFileReceived;

  FileReceiver({required this.port, required this.onFileReceived});

  void startReceiverServer() async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
    );
    print('Server running on http://${server.address.address}:${server.port}');

    await for (HttpRequest request in server) {
      handleRequest(request);
    }
  }

  void handleRequest(HttpRequest request) async {
    try {
      if (request.method == 'POST' && request.uri.path == '/upload') {
        final ContentType? contentType = request.headers.contentType;
        if (contentType == null ||
            !contentType.mimeType.startsWith('multipart/form-data')) {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..write('Invalid content type');
          return;
        }

        final String? boundary = contentType.parameters['boundary'];
        final MimeMultipartTransformer transformer = MimeMultipartTransformer(
          boundary!,
        );
        final List<MimeMultipart> parts =
            await transformer.bind(request).toList();

        for (final MimeMultipart part in parts) {
          final Map<String, String> headers = part.headers;
          final String? contentDisposition = headers['content-disposition'];

          final RegExp filenameRegex = RegExp(r'filename="(.+)"');
          final RegExpMatch? match = filenameRegex.firstMatch(
            contentDisposition!,
          );
          final String filename = match?.group(1) ?? 'received_file';

          final Directory tempDir = await getTemporaryDirectory();
          final String tempFilePath =
              '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$filename';
          final File tempFile = File(tempFilePath);
          await tempFile.writeAsBytes(
            await part.toList().then(
              (parts) => parts.expand((e) => e).toList(),
            ),
          );

          final bool? success = await copyFileIntoDownloadFolder(
            tempFilePath,
            filename,
          );

          if (success == true) {
            onFileReceived?.call(
              "File received: $filename in downloads folder",
            );
            request.response
              ..statusCode = HttpStatus.ok
              ..write('Upload received and saved as $filename');
          } else {
            request.response
              ..statusCode = HttpStatus.internalServerError
              ..write('Failed to save file');
          }
        }
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
      }
    } catch (e) {
      onFileReceived?.call("Error receiving file");
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Error: $e');
    } finally {
      await request.response.close();
    }
  }
}
