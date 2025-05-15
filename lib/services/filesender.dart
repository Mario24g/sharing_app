import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'package:sharing_app/model/device.dart';

class FileSender {
  final int port;

  FileSender({required this.port});

  Future sendMetadata(String targetIp, int fileCount) async {
    final Uri uri = Uri.parse('http://$targetIp:8889/upload-metadata');
    await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fileCount': fileCount}),
    );
  }

  void createTransferTask(
    List<Device> selectedDevices,
    List<File> selectedFiles,
    void Function(String message)? onTransferComplete,
    void Function(double progress)? onProgressUpdate,
    void Function(String statusMessage)? onStatusUpdate,
  ) async {
    final List<Future> uploadTasks = [];
    final int totalFiles = selectedDevices.length * selectedFiles.length;
    int completedFiles = 0;

    for (final Device device in selectedDevices) {
      await sendMetadata(device.ip, selectedFiles.length);

      for (final File file in selectedFiles) {
        uploadTasks.add(
          sendFile(
            device.ip,
            file,
            () {
              onStatusUpdate?.call(
                "Transfering ${basename(file.path)} to ${device.name}",
              );
            },
            (progress) {
              onProgressUpdate?.call(progress);

              if (progress >= 1.0) {
                completedFiles++;
                onStatusUpdate?.call(
                  "Transferred ${basename(file.path)} to ${device.name} ($completedFiles/$totalFiles)",
                );
              }
            },
          ),
        );
      }
    }

    await Future.wait(uploadTasks);

    onTransferComplete?.call(
      "Transferred ${selectedFiles.length} file(s) to ${selectedDevices.length} device(s)",
    );
  }

  Future sendFile(
    String targetIp,
    File file,
    void Function()? onTransferStarted,
    void Function(double progress)? onProgress,
  ) async {
    onTransferStarted?.call();
    Uri uri = Uri.parse('http://$targetIp:8889/upload');
    int length = await file.length();
    //ByteStream stream = http.ByteStream(file.openRead());
    ByteStream stream = http.ByteStream(
      _ProgressStream(file.openRead(), length, onProgress!),
    );
    stream.cast();

    MultipartRequest request = http.MultipartRequest("POST", uri);

    MultipartFile multipartFile = http.MultipartFile(
      "file",
      stream,
      length,
      filename: basename(file.path),
    );

    request.files.add(multipartFile);

    await request
        .send()
        .then((response) async {
          response.stream.transform(utf8.decoder).listen((value) {
            print(value);
          });
        })
        .catchError((e) {
          print(e);
        });
  }
}

class _ProgressStream extends Stream<List<int>> {
  final Stream<List<int>> _stream;
  final int _total;
  final void Function(double) _onProgress;
  int _bytesSent = 0;

  _ProgressStream(this._stream, this._total, this._onProgress);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      (chunk) {
        _bytesSent += chunk.length;
        double progress = _bytesSent / _total;
        _onProgress(progress);
        if (onData != null) onData(chunk);
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
