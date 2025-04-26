import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

class FileSender {
  final int port;
  ServerSocket? server;
  File? fileToTransfer;

  FileSender({required this.port});

  Future sendFile(
    String targetIp,
    File file,
    void Function(double progress) onProgress,
  ) async {
    // string to uri
    Uri uri = Uri.parse('http://$targetIp:8889/upload');
    int length = await file.length();
    // open a byteStream
    //ByteStream stream = http.ByteStream(file.openRead());
    ByteStream stream = http.ByteStream(
      _ProgressStream(file.openRead(), length, onProgress),
    );
    stream.cast();
    // get file length

    // create multipart request
    MultipartRequest request = http.MultipartRequest("POST", uri);

    // multipart that takes file.. here this "image_file" is a key of the API request
    MultipartFile multipartFile = http.MultipartFile(
      "file",
      stream,
      length,
      filename: basename(file.path),
    );

    // add file to multipart
    request.files.add(multipartFile);

    // send request to upload image
    await request
        .send()
        .then((response) async {
          // listen for response
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
