import 'dart:convert';
import 'dart:io';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:blitzshare/main.dart';
import 'package:blitzshare/model/device.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FileReceiver {
  final int port;
  final AppState appState;
  final BuildContext context;
  //final void Function(String message)? onFileReceived;
  final void Function(String message, Device senderDevice, List<File> files)? onFileReceived;

  final Map<String, int> _expectedFiles = {};
  final Map<String, int> _receivedFiles = {};
  final List<File> files = [];

  FileReceiver({required this.port, required this.appState, required this.context, required this.onFileReceived});

  void startReceiverServer({required String Function(int, String) filesReceivedMessage, required String Function(String) errorReceivingMessage}) async {
    final HttpServer server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    await for (HttpRequest request in server) {
      if (request.method == "POST" && request.uri.path == "/upload-metadata") {
        await _handleMetadata(request);
      } else if (request.method == "POST" && request.uri.path == "/upload") {
        await _handleFileUpload(request, filesReceivedMessage, errorReceivingMessage);
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write("Not found")
          ..close();
      }
    }
  }

  Future _handleMetadata(HttpRequest request) async {
    final String content = await utf8.decoder.bind(request).join();
    final dynamic data = jsonDecode(content);
    final String ip = request.connectionInfo?.remoteAddress.address ?? "unknown";

    final int expected = data["fileCount"] ?? 1;
    _expectedFiles[ip] = expected;
    _receivedFiles[ip] = 0;

    request.response
      ..statusCode = HttpStatus.ok
      ..write("Metadata received")
      ..close();
  }

  Future _handleFileUpload(
    HttpRequest request,
    String Function(int fileCount, String ip) filesReceivedMessage,
    String Function(String deviceName) errorReceivingMessage,
  ) async {
    final String ip = request.connectionInfo?.remoteAddress.address ?? "unknown";
    final Device senderDevice = appState.devices.firstWhere(
      (device) => device.ip == ip,
      orElse: () => Device(ip: ip, name: "Unknown Device", devicePlatform: DevicePlatform.unknown),
    );

    try {
      final ContentType? contentType = request.headers.contentType;
      if (contentType == null || !contentType.mimeType.startsWith("multipart/form-data")) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write("Invalid content type")
          ..close();
        return;
      }

      final String boundary = contentType.parameters["boundary"]!;
      final List<MimeMultipart> parts = await MimeMultipartTransformer(boundary).bind(request).toList();

      for (final MimeMultipart part in parts) {
        final Map<String, String> headers = part.headers;
        final RegExpMatch? match = RegExp(r'filename="(.+)"').firstMatch(headers["content-disposition"] ?? "");
        final String filename = match?.group(1) ?? "received_file";

        final Directory tempDir = await getTemporaryDirectory();
        final String tempFilePath = "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$filename";
        final File file = File(tempFilePath);
        /*await file.writeAsBytes(
          await part.toList().then((parts) => parts.expand((e) => e).toList()),
        );*/
        files.add(file);
        final IOSink sink = file.openWrite();
        await part.pipe(sink);
        await sink.flush();
        await sink.close();

        final bool? success = await copyFileIntoDownloadFolder(tempFilePath, filename);
        if (!success!) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write("Failed to save file")
            ..close();
          return;
        }

        _receivedFiles[ip] = (_receivedFiles[ip] ?? 0) + 1;
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..write("File(s) uploaded successfully")
        ..close();

      if (_receivedFiles[ip] == _expectedFiles[ip]) {
        onFileReceived?.call("${_receivedFiles[ip]} file(s) received from $ip", senderDevice, files);
        //onFileReceived?.call(AppLocalizations.of(context)!.filesReceived(_receivedFiles[ip]!, ip), senderDevice, files);
        //onFileReceived?.call(filesReceivedMessage(_receivedFiles[ip]!, ip), senderDevice, files);
        _expectedFiles.remove(ip);
        _receivedFiles.remove(ip);
      }
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write("Error: $e")
        ..close();
      onFileReceived?.call("Error receiving file from ${senderDevice.name}", senderDevice, List.empty());
      //onFileReceived?.call(AppLocalizations.of(context)!.errorReceiving(senderDevice.name), senderDevice, List.empty());
      //onFileReceived?.call(errorReceivingMessage(senderDevice.name), senderDevice, List.empty());
    }
  }
}
