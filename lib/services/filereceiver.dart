import "dart:convert";
import "dart:io";

import "package:blitzshare/services/transferservice.dart";
import "package:downloadsfolder/downloadsfolder.dart";
import "package:mime/mime.dart";
import "package:path_provider/path_provider.dart";
import "package:blitzshare/main.dart";
import "package:blitzshare/model/device.dart";

class FileReceiver {
  final int port;
  final AppState appState;
  final void Function(String message, Device senderDevice, List<File> files)? onFileReceived;

  final Map<String, TransferSession> _sessions = {};
  HttpServer? _server;
  bool _isRunning = false;
  final int bufferSize = 8 * 1024;

  FileReceiver({required this.port, required this.appState, required this.onFileReceived});

  Future<bool> startReceiverServer({required String Function(int, String) filesReceivedMessage, required String Function(String) errorReceivingMessage}) async {
    if (_isRunning) return true;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port, backlog: 50);
      _isRunning = true;

      _server!.defaultResponseHeaders.clear();
      _server!.autoCompress = false;

      _server!.listen((HttpRequest request) async {
        try {
          await _handleRequest(request, filesReceivedMessage, errorReceivingMessage);
        } catch (e) {
          _sendErrorResponse(request, "Internal server error");
        }
      });

      return true;
    } catch (e) {
      _isRunning = false;
      return false;
    }
  }

  Future stopReceiverServer() async {
    if (!_isRunning || _server == null) return;

    _isRunning = false;
    _sessions.clear();

    await _server!.close(force: true);
    _server = null;
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
      } else if (method == "GET" && path == "/status") {
        await _handleStatusRequest(request);
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

      _sessions[ip] = TransferSession(expectedFiles: expected, receivedFiles: 0, files: [], startTime: DateTime.now(), lastActivity: DateTime.now());

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

      session.lastActivity = DateTime.now();

      final String? boundary = contentType.parameters["boundary"];
      if (boundary == null) {
        _sendErrorResponse(request, "Invalid multipart format", HttpStatus.badRequest);
        return;
      }

      bool fileProcessed = false;
      await for (final MimeMultipart part in MimeMultipartTransformer(boundary).bind(request)) {
        if (!_isRunning) {
          _sendErrorResponse(request, "Server shutting down");
          return;
        }

        final File? savedFile = await _processFilePart(part, session, senderDevice);
        if (savedFile != null) {
          session.files.add(savedFile);
          fileProcessed = true;
        }
      }

      if (fileProcessed) {
        session.receivedFiles++;
        session.lastActivity = DateTime.now();

        _sendSuccessResponse(request, "File uploaded successfully");

        if (session.receivedFiles >= session.expectedFiles) {
          onFileReceived?.call(filesReceivedMessage(session.receivedFiles, senderDevice.name), senderDevice, session.files);
          _sessions.remove(ip);
        }
      } else {
        _sendErrorResponse(request, "No file received");
      }
    } catch (e) {
      _sendErrorResponse(request, "Upload failed: $e");
      onFileReceived?.call(errorReceivingMessage(senderDevice.name), senderDevice, []);
    }
  }

  Future<File?> _processFilePart(MimeMultipart part, TransferSession session, Device senderDevice) async {
    try {
      final Map<String, String> headers = part.headers;
      final RegExpMatch? match = RegExp(r'filename="([^"]+)"').firstMatch(headers["content-disposition"] ?? "");
      final String filename = match?.group(1) ?? "received_file_${DateTime.now().millisecondsSinceEpoch}";

      final Directory tempDir = await getTemporaryDirectory();
      final String tempFilePath = "${tempDir.path}/$filename";
      final File tempFile = File(tempFilePath);

      final File uniqueTempFile = await _ensureUniqueFilename(tempFile);

      final IOSink sink = uniqueTempFile.openWrite();
      int bytesWritten = 0;
      try {
        await for (final List<int> chunk in part) {
          if (!_isRunning) {
            throw Exception("Server shutting down");
          }
          sink.add(chunk);
          bytesWritten += chunk.length;

          if (bytesWritten % (bufferSize * 4) == 0) {
            await sink.flush();
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (!await uniqueTempFile.exists()) {
        throw Exception("Temporary file was not created");
      }

      await copyFileIntoDownloadFolder(uniqueTempFile.path, filename);
      await uniqueTempFile.delete();

      final Directory? downloadsDir = await _getDownloadsDirectory();
      if (downloadsDir != null) {
        final File finalFile = File('${downloadsDir.path}/$filename');
        return finalFile;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  //~/storage/shared/Android/data/com.projects.blitzshare/files/Downloads/
  //---- COULD BE Download OR Downloads
  Future<Directory?> _getDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        final Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final Directory appDownloads = Directory("${externalDir.path}/Downloads");
          if (!await appDownloads.exists()) {
            await appDownloads.create(recursive: true);
          }
          return appDownloads;
        }

        final Directory documentsDir = await getApplicationDocumentsDirectory();
        final Directory appDownloads = Directory("${documentsDir.path}/Downloads");
        if (!await appDownloads.exists()) {
          await appDownloads.create();
        }
        return appDownloads;
      } else if (Platform.isIOS) {
        final Directory documentsDir = await getApplicationDocumentsDirectory();
        final Directory appDownloads = Directory("${documentsDir.path}/Downloads");
        if (!await appDownloads.exists()) {
          await appDownloads.create();
        }
        return appDownloads;
      } else {
        try {
          return await getDownloadsDirectory();
        } catch (e) {
          final Directory documentsDir = await getApplicationDocumentsDirectory();
          final Directory appDownloads = Directory("${documentsDir.path}/Downloads");
          if (!await appDownloads.exists()) {
            await appDownloads.create();
          }
          return appDownloads;
        }
      }
    } catch (e) {
      try {
        final Directory documentsDir = await getApplicationDocumentsDirectory();
        final Directory appDownloads = Directory("${documentsDir.path}/Downloads");
        if (!await appDownloads.exists()) {
          await appDownloads.create();
        }
        return appDownloads;
      } catch (e2) {
        return await getApplicationDocumentsDirectory();
      }
    }
  }

  Future<File> _ensureUniqueFilename(File originalFile) async {
    File currentFile = originalFile;
    int counter = 1;

    while (await currentFile.exists()) {
      final String directory = dirname(originalFile.path);
      final String nameWithoutExtension = basenameWithoutExtension(originalFile.path);
      final String extensionStr = extension(originalFile.path);

      final String newName = "${nameWithoutExtension}_$counter$extensionStr";
      currentFile = File("$directory/$newName");
      counter++;
    }

    return currentFile;
  }

  Future _handleStatusRequest(HttpRequest request) async {
    final Map<String, dynamic> status = {
      "running": _isRunning,
      "port": port,
      "activeSessions": _sessions.length,
      "sessionDetails": _sessions.map(
        (ip, session) => MapEntry(ip, {
          "expectedFiles": session.expectedFiles,
          "receivedFiles": session.receivedFiles,
          "startTime": session.startTime.toIso8601String(),
          "lastActivity": session.lastActivity.toIso8601String(),
        }),
      ),
    };

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(status))
      ..close();
  }

  Device _getSenderDevice(String ip) {
    return appState.devices.firstWhere(
      (device) => device.ip == ip,
      orElse: () => Device(ip: ip, name: "Unknown Device ($ip)", devicePlatform: DevicePlatform.unknown),
    );
  }

  void _sendSuccessResponse(HttpRequest request, String message) {
    try {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.text
        ..write(message)
        ..close();
    } catch (_) {}
  }

  void _sendErrorResponse(HttpRequest request, String message, [int statusCode = HttpStatus.internalServerError]) {
    try {
      request.response
        ..statusCode = statusCode
        ..headers.contentType = ContentType.text
        ..write(message)
        ..close();
    } catch (_) {}
  }

  void cleanupStaleSessions({Duration timeout = const Duration(minutes: 10)}) {
    final DateTime now = DateTime.now();
    final List<String> staleIps = [];

    for (final entry in _sessions.entries) {
      if (now.difference(entry.value.lastActivity) > timeout) {
        staleIps.add(entry.key);
      }
    }

    for (final String ip in staleIps) {
      _sessions.remove(ip);
    }
  }
}
