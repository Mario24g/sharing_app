import "dart:async";
import "dart:convert";
import "dart:io";

import "package:blitzshare/services/transferservice.dart";
import "package:flutter/widgets.dart";
import "package:http/http.dart";
import "package:http_parser/http_parser.dart";
import "package:path/path.dart";
import "package:http/http.dart" as http;
import "package:blitzshare/model/device.dart";
import "package:path/path.dart" as path;

class FileSender {
  final BuildContext context;
  final int chunkSize;
  final Duration requestTimeout;

  bool _isCancelled = false;
  final List<StreamSubscription> _activeSubscriptions = [];
  final List<http.MultipartRequest> _activeRequests = [];

  FileSender({required this.context, this.chunkSize = 64 * 1024, this.requestTimeout = const Duration(minutes: 30)});

  void cancelTransfer() {
    _isCancelled = true;

    for (final StreamSubscription subscription in _activeSubscriptions) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();

    //HTTP requests cant be directly cancelled in Dart, but we can ignore their responses
    _activeRequests.clear();
  }

  void resetCancellation() {
    _isCancelled = false;
    _activeSubscriptions.clear();
    _activeRequests.clear();
  }

  Future<bool> sendMetadata(String targetIp, int fileCount) async {
    if (_isCancelled) return false;

    try {
      final Uri uri = Uri.parse("http://$targetIp:8889/upload-metadata");
      final response = await http
          .post(uri, headers: {"Content-Type": "application/json"}, body: jsonEncode({"fileCount": fileCount}))
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print("Error sending metadata: $e");
      return false;
    }
  }

  Future<TransferResult> createTransferTask(
    List<Device> selectedDevices,
    List<File> selectedFiles,
    void Function(String message)? onTransferComplete,
    void Function(double progress)? onProgressUpdate,
    void Function(String statusMessage)? onStatusUpdate, {
    required String Function(String filePath, String deviceName) statusUpdateTransferring,
    required String Function(String filePath, String deviceName) statusUpdateTransferred,
    required String Function(int fileCount, int deviceCount) transferComplete,
    void Function(String error)? onError,
  }) async {
    resetCancellation();

    final int totalFiles = selectedDevices.length * selectedFiles.length;
    int completedFiles = 0;
    final List<String> failedTransfers = [];

    try {
      for (final Device device in selectedDevices) {
        if (_isCancelled) {
          return TransferResult(success: false, completedFiles: completedFiles, totalFiles: totalFiles, cancelled: true, errors: failedTransfers);
        }

        final bool metadataSuccess = await sendMetadata(device.ip, selectedFiles.length);
        if (!metadataSuccess) {
          final String error = "Failed to send metadata to ${device.name}";
          failedTransfers.add(error);
          onError?.call(error);
          continue;
        }

        for (final File file in selectedFiles) {
          if (_isCancelled) {
            return TransferResult(success: false, completedFiles: completedFiles, totalFiles: totalFiles, cancelled: true, errors: failedTransfers);
          }

          try {
            onStatusUpdate?.call(statusUpdateTransferring(basename(file.path), device.name));

            final bool success = await sendFile(device.ip, file, onProgressUpdate);

            if (success) {
              completedFiles++;
              onStatusUpdate?.call("${statusUpdateTransferred(basename(file.path), device.name)} ($completedFiles/$totalFiles)");
            } else {
              final String error = "Failed to transfer ${basename(file.path)} to ${device.name}";
              failedTransfers.add(error);
              onError?.call(error);
            }
          } catch (e) {
            final String error = "Error transferring ${basename(file.path)} to ${device.name}: $e";
            failedTransfers.add(error);
            onError?.call(error);
          }
        }
      }

      if (!_isCancelled) {
        onTransferComplete?.call(transferComplete(selectedFiles.length, selectedDevices.length));
      }

      return TransferResult(
        success: !_isCancelled && failedTransfers.isEmpty,
        completedFiles: completedFiles,
        totalFiles: totalFiles,
        cancelled: _isCancelled,
        errors: failedTransfers,
      );
    } catch (e) {
      onError?.call("Transfer task error: $e");
      return TransferResult(
        success: false,
        completedFiles: completedFiles,
        totalFiles: totalFiles,
        cancelled: _isCancelled,
        errors: [...failedTransfers, e.toString()],
      );
    }
  }

  Future<bool> sendFile(String targetIp, File file, void Function(double progress)? onProgress) async {
    if (_isCancelled) return false;

    try {
      final Uri uri = Uri.parse("http://$targetIp:8889/upload");
      final int fileSize = await file.length();

      final Stream<List<int>> fileStream = _createStream(file, fileSize, onProgress);
      final ByteStream byteStream = http.ByteStream(fileStream);

      final MultipartRequest request = http.MultipartRequest("POST", uri);
      _activeRequests.add(request);

      final MultipartFile multipartFile = http.MultipartFile(
        "file",
        byteStream,
        fileSize,
        filename: basename(file.path),
        contentType: _getContentType(file.path),
      );

      request.files.add(multipartFile);

      request.headers.addAll({"Connection": "keep-alive", "Accept-Encoding": "gzip, deflate"});

      if (_isCancelled) return false;

      final response = await request.send().timeout(requestTimeout);

      _activeRequests.remove(request);

      if (_isCancelled) return false;

      if (response.statusCode == 200) {
        await response.stream.drain();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Stream<List<int>> _createStream(File file, int fileSize, void Function(double progress)? onProgress) {
    return Stream.fromFuture(_readFileInChunks(file, fileSize, onProgress));
  }

  Future<List<int>> _readFileInChunks(File file, int fileSize, void Function(double progress)? onProgress) async {
    final List<int> allBytes = [];
    int bytesRead = 0;

    final RandomAccessFile raf = await file.open();

    try {
      while (bytesRead < fileSize && !_isCancelled) {
        final int remainingBytes = fileSize - bytesRead;
        final int currentChunkSize = remainingBytes < chunkSize ? remainingBytes : chunkSize;

        final List<int> chunk = await raf.read(currentChunkSize);
        if (chunk.isEmpty) break;

        allBytes.addAll(chunk);
        bytesRead += chunk.length;

        if (onProgress != null) {
          final double progress = bytesRead / fileSize;
          onProgress(progress);
        }

        await Future.delayed(Duration.zero);
      }
    } finally {
      await raf.close();
    }

    return allBytes;
  }

  MediaType? _getContentType(String filePath) {
    final String extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case ".jpg":
      case ".jpeg":
        return MediaType("image", "jpeg");
      case ".png":
        return MediaType("image", "png");
      case ".pdf":
        return MediaType("application", "pdf");
      case ".txt":
        return MediaType("text", "plain");
      case ".mp4":
        return MediaType("video", "mp4");
      case ".mp3":
        return MediaType("audio", "mpeg");
      default:
        return MediaType("application", "octet-stream");
    }
  }
}
