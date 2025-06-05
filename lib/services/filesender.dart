import "dart:async";
import "dart:convert";
import "dart:io";

import "package:blitzshare/services/transferservice.dart";
import "package:http/http.dart";
import "package:http_parser/http_parser.dart";
import "package:path/path.dart";
import "package:blitzshare/model/device.dart";

class FileSender {
  final int port;
  final Duration requestTimeout;

  bool _isCancelled = false;
  final List<StreamSubscription> _activeSubscriptions = [];
  final List<Client> _activeClients = [];

  FileSender({required this.port, this.requestTimeout = const Duration(minutes: 2)});

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
    _resetCancellation();

    final int totalFiles = selectedDevices.length * selectedFiles.length;
    int completedFiles = 0;
    final List<String> failedTransfers = [];

    try {
      for (final Device device in selectedDevices) {
        if (_isCancelled) {
          return TransferResult(success: false, completedFiles: completedFiles, totalFiles: totalFiles, cancelled: true, errors: failedTransfers);
        }

        final bool metadataSuccess = await _sendMetadata(device.ip, selectedFiles.length);
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

            final bool success = await _sendFile(device.ip, file, (progress) {
              final double fileProgress = (completedFiles + progress) / totalFiles;
              onProgressUpdate?.call(fileProgress);
            });

            if (success) {
              completedFiles++;
              onStatusUpdate?.call("${statusUpdateTransferred(basename(file.path), device.name)} ($completedFiles/$totalFiles)");
              onProgressUpdate?.call(completedFiles / totalFiles);
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

  Future<bool> _sendMetadata(String targetIp, int fileCount) async {
    if (_isCancelled) return false;

    Client? client;
    try {
      client = Client();
      _activeClients.add(client);

      final Uri uri = Uri.parse("http://$targetIp:$port/upload-metadata");
      final response = await client
          .post(uri, headers: {"Content-Type": "application/json"}, body: jsonEncode({"fileCount": fileCount}))
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    } finally {
      if (client != null) {
        _activeClients.remove(client);
        client.close();
      }
    }
  }

  Future<bool> _sendFile(String targetIp, File file, void Function(double progress)? onProgress) async {
    if (_isCancelled) return false;

    Client? client;
    try {
      client = Client();
      _activeClients.add(client);

      final Uri uri = Uri.parse("http://$targetIp:$port/upload");
      final int fileSize = await file.length();

      final Stream<List<int>> progressStream = _createProgressStream(file.openRead(), fileSize, onProgress);
      final ByteStream byteStream = ByteStream(progressStream);

      final MultipartRequest request = MultipartRequest("POST", uri);
      final MultipartFile multipartFile = MultipartFile("file", byteStream, fileSize, filename: basename(file.path), contentType: _getContentType(file.path));

      request.files.add(multipartFile);
      request.headers.addAll({'Connection': 'keep-alive', 'Accept-Encoding': 'gzip, deflate'});

      if (_isCancelled) return false;

      final StreamedResponse streamedResponse = await client.send(request).timeout(requestTimeout);

      if (_isCancelled) return false;

      if (streamedResponse.statusCode == 200) {
        await streamedResponse.stream.drain();
        return true;
      } else {
        await streamedResponse.stream.bytesToString();
        return false;
      }
    } catch (e) {
      if (!_isCancelled) {}
      return false;
    } finally {
      if (client != null) {
        _activeClients.remove(client);
        client.close();
      }
    }
  }

  Stream<List<int>> _createProgressStream(Stream<List<int>> sourceStream, int totalBytes, void Function(double progress)? onProgress) {
    int bytesSent = 0;

    return sourceStream.map((chunk) {
      if (_isCancelled) {
        throw Exception("Transfer cancelled");
      }

      bytesSent += chunk.length;
      final double progress = bytesSent / totalBytes;
      onProgress?.call(progress);

      return chunk;
    });
  }

  MediaType? _getContentType(String filePath) {
    final String extensionStr = extension(filePath).toLowerCase();
    switch (extensionStr) {
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

  void cancelTransfer() {
    _isCancelled = true;

    for (final StreamSubscription subscription in _activeSubscriptions) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();

    for (final Client client in _activeClients) {
      client.close();
    }
    _activeClients.clear();
  }

  void _resetCancellation() {
    _isCancelled = false;
    _activeSubscriptions.clear();
    _activeClients.clear();
  }

  void dispose() {
    cancelTransfer();
  }
}
