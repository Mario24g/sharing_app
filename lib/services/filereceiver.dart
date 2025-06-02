import "dart:convert";
import "dart:io";

import "package:blitzshare/services/transferservice.dart";
import "package:downloadsfolder/downloadsfolder.dart";
import "package:flutter/material.dart";
import "package:mime/mime.dart";
import "package:path_provider/path_provider.dart";
import "package:blitzshare/main.dart";
import "package:blitzshare/model/device.dart";

class FileReceiver {
  final int port;
  final AppState appState;
  final BuildContext context;
  final void Function(String message, Device senderDevice, List<File> files)? onFileReceived;

  final Map<String, TransferSession> _sessions = {};
  HttpServer? _server;
  bool _isRunning = false;
  final int bufferSize = 64 * 1024;

  FileReceiver({required this.port, required this.appState, required this.context, required this.onFileReceived});

  Future<bool> startReceiverServer({required String Function(int, String) filesReceivedMessage, required String Function(String) errorReceivingMessage}) async {
    if (_isRunning) return true;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port, backlog: 50);

      _isRunning = true;

      _server!.defaultResponseHeaders.clear();
      _server!.autoCompress = false;

      _server!.listen((HttpRequest request) {
        _handleRequest(request, filesReceivedMessage, errorReceivingMessage).catchError((error) {
          _sendErrorResponse(request, "Internal server error");
        });
      });

      return true;
    } catch (e) {
      _isRunning = false;
      return false;
    }
  }

  Future stopReceiverServer() async {
    if (!_isRunning || _server == null) return;

    try {
      _isRunning = false;
      _sessions.clear();

      await _server!.close(force: true);
      _server = null;
    } catch (e) {
      print("Error stopping receiver server: $e");
    }
  }

  Future _handleRequest(HttpRequest request, String Function(int, String) filesReceivedMessage, String Function(String) errorReceivingMessage) async {
    if (!_isRunning) {
      _sendErrorResponse(request, "Server is shutting down");
      return;
    }

    try {
      final String path = request.uri.path;
      final String method = request.method;

      if (method == "POST" && path == "/upload-metadata") {
        await _handleMetadata(request);
      } else if (method == "POST" && path == "/upload") {
        await _handleFileUpload(request, filesReceivedMessage, errorReceivingMessage);
      } else {
        _sendErrorResponse(request, "Not found", HttpStatus.notFound);
      }
    } catch (e) {
      _sendErrorResponse(request, "Internal server error");
    }
  }

  Future _handleMetadata(HttpRequest request) async {
    try {
      final String content = await utf8.decoder.bind(request).join();
      final dynamic data = jsonDecode(content);
      final String ip = request.connectionInfo?.remoteAddress.address ?? "unknown";

      final int expected = data["fileCount"] ?? 1;

      _sessions[ip] = TransferSession(expectedFiles: expected, receivedFiles: 0, files: []);

      _sendSuccessResponse(request, "Metadata received");
    } catch (e) {
      _sendErrorResponse(request, "Invalid metadata format");
    }
  }

  Future _handleFileUpload(
    HttpRequest request,
    String Function(int fileCount, String ip) filesReceivedMessage,
    String Function(String deviceName) errorReceivingMessage,
  ) async {
    final String ip = request.connectionInfo?.remoteAddress.address ?? "unknown";
    final Device senderDevice = _getSenderDevice(ip);

    try {
      final ContentType? contentType = request.headers.contentType;
      if (contentType == null || !contentType.mimeType.startsWith("multipart/form-data")) {
        _sendErrorResponse(request, "Invalid content type", HttpStatus.badRequest);
        return;
      }

      final TransferSession? session = _sessions[ip];
      if (session == null) {
        _sendErrorResponse(request, "No metadata received", HttpStatus.badRequest);
        return;
      }

      final String boundary = contentType.parameters["boundary"]!;

      await for (final MimeMultipart part in MimeMultipartTransformer(boundary).bind(request)) {
        if (!_isRunning) {
          _sendErrorResponse(request, "Server shutting down");
          return;
        }

        final File? savedFile = await _processFilePart(part, session, senderDevice);
        if (savedFile != null) {
          session.files.add(savedFile);
        }
      }

      session.receivedFiles++;

      _sendSuccessResponse(request, "File uploaded successfully");

      if (session.receivedFiles >= session.expectedFiles) {
        onFileReceived?.call(filesReceivedMessage(session.receivedFiles, senderDevice.name), senderDevice, session.files);

        _sessions.remove(ip);
      }
    } catch (e) {
      _sendErrorResponse(request, "Upload failed: $e");
      onFileReceived?.call(errorReceivingMessage(senderDevice.name), senderDevice, List.empty());
    }
  }

  Future<File?> _processFilePart(MimeMultipart part, TransferSession session, Device senderDevice) async {
    try {
      final Map<String, String> headers = part.headers;
      final RegExpMatch? match = RegExp(r'filename="(.+)"').firstMatch(headers["content-disposition"] ?? "");
      final String filename = match?.group(1) ?? "received_file_${DateTime.now().millisecondsSinceEpoch}";

      final Directory tempDir = await getTemporaryDirectory();
      final String tempFilePath = "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$filename";
      final File tempFile = File(tempFilePath);

      final IOSink sink = tempFile.openWrite();

      try {
        await part.pipe(sink);
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (!await tempFile.exists() || await tempFile.length() == 0) {
        throw Exception("File was not properly saved");
      }

      final bool success = await _moveFileToDownloads(tempFilePath, filename);

      if (success) {
        return tempFile;
      } else {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        throw Exception("Failed to move file to downloads folder");
      }
    } catch (e) {
      print("Error processing file part: $e");
      return null;
    }
  }

  Future<bool> _moveFileToDownloads(String tempPath, String filename) async {
    try {
      return await copyFileIntoDownloadFolder(tempPath, filename) ?? false;
    } catch (e) {
      print("Error moving file to downloads: $e");
      return false;
    }
  }

  Device _getSenderDevice(String ip) {
    return appState.devices.firstWhere(
      (device) => device.ip == ip,
      orElse: () => Device(ip: ip, name: "Unknown Device", devicePlatform: DevicePlatform.unknown),
    );
  }

  void _sendSuccessResponse(HttpRequest request, String message) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.text
      ..write(message)
      ..close();
  }

  void _sendErrorResponse(HttpRequest request, String message, [int statusCode = HttpStatus.internalServerError]) {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.text
      ..write(message)
      ..close();
  }
}
