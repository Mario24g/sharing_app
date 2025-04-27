import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart';
import 'package:sharing_app/model/device.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;

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

class FileTransferManager {
  final int _port = 8890;
  ServerSocket? server;
  File? fileToTransfer;

  Future<void> sendFile(String targetIp, File file) async {
    final url = Uri.parse('http://$targetIp:8889/upload');
    final bytes = await file.readAsBytes();

    try {
      final response = await http.post(
        url,
        headers: {HttpHeaders.contentTypeHeader: 'application/octet-stream'},
        body: bytes,
      );

      if (response.statusCode == 200) {
        print("File sent successfully");
      } else {
        print("Failed to send file. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error sending file: $e");
    }
  }

  Future sendFile1(
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

  ////
  /*void startTransfer(File file, Device targetDevice) async {
    final NetworkInfo networkInfo = NetworkInfo();
    final String localIp = await networkInfo.getWifiIP() ?? '0.0.0.0';
    final String notification = "SEND:$localIp:$_port";

    ServerSocket server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      _port,
      shared: true,
    );

    print(
      "Transfer server started at ${server.address.address}:${server.port}",
    );

    await Future.delayed(Duration(milliseconds: 300));

    try {
      final Socket socket = await Socket.connect(targetDevice.ip, 8890);
      print("Connected to target ${targetDevice.ip}");

      socket.writeln(notification);
      await socket.flush();
      await socket.close();
    } catch (e) {
      print("Failed to notify target device: $e");
    }

    await Future.delayed(Duration(milliseconds: 300));

    server.listen((client) async {
      print(
        "Target connected to receive file: ${client.remoteAddress.address}",
      );
      final String fileName = file.path.split('/').last;
      final int fileLength = await file.length();
      client.writeln("$fileName:$fileLength");
      await client.flush();

      await file.openRead().pipe(client);
      await client.flush();
      await client.close();

      print("File sent to ${client.remoteAddress.address}");
    });
  }*/

  void notifyTransfer(File file, Device targetDevice) async {
    final NetworkInfo networkInfo = NetworkInfo();
    final String localIp = await networkInfo.getWifiIP() ?? '0.0.0.0';
    final String notification = "NOTIFICATION:$localIp:$_port";
    fileToTransfer = file;

    try {
      final Socket socket = await Socket.connect(targetDevice.ip, 8890);

      socket.writeln(notification);
      await socket.flush();
      await socket.close();
    } catch (e) {
      print("Failed to notify target device: $e");
    }

    /*server.listen((client) async {
      print(
        "Target connected to receive file: ${client.remoteAddress.address}",
      );
      final String fileName = file.path.split('/').last;
      final int fileLength = await file.length();
      client.writeln("$fileName:$fileLength");
      await client.flush();

      await file.openRead().pipe(client);
      await client.flush();
      await client.close();

      print("File sent to ${client.remoteAddress.address}");
    });*/
  }

  /*void startTransfer(File file, Device targetDevice) async {
    NetworkInfo networkInfo = NetworkInfo();
    ServerSocket server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      shared: true,
      _port,
    );
    print("Server started at ${server.address.address}:${server.port}");

    final String notification = "SEND:${await networkInfo.getWifiIP()}:$_port";
    server.listen((client) async {
      print("Client connected: ${client.remoteAddress.address}");
      client.writeln(notification);
      await client.flush();
      await client.close();
    });
  }*/

  void startServer(File file) async {
    final ServerSocket server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      shared: true,
      _port,
    );
    print("Server started at ${server.address.address}:${server.port}");

    server.listen((client) async {
      print("Client to transfer connected");
      final String fileName = file.path.split(Platform.pathSeparator).last;
      final int fileLength = await file.length();
      client.writeln('$fileName:$fileLength');

      await file.openRead().pipe(client);
      await client.flush();
      await client.close();

      await server.close();
    });
  }

  void startClient(String senderIp) async {
    final Socket socket = await Socket.connect(senderIp, _port);
    try {
      print(
        "Connected from target to:"
        '${socket.remoteAddress.address}:${socket.remotePort}',
      );
      socket.listen(
        (data) async {
          String message = String.fromCharCodes(data).trim();
          print(message);
          List<String> split = message.split(":");
          String fileName = split[0];
          int fileLength = int.parse(split[1]);

          IOSink iosink = File(fileName).openWrite();
          try {
            await socket.map(toIntList).pipe(iosink);
          } finally {
            iosink.close();
          }
        },
        onDone: () {
          socket.destroy();
        },
      );
    } finally {
      socket.destroy();
    }

    /*try {
      print(
        "Connected to:"
        '${socket.remoteAddress.address}:${socket.remotePort}',
      );
      //final reader = socket.transform(utf8.decoder).transform(LineSplitter());

      socket.write('Send Data');

      IOSink iosink = File('received.png').openWrite();
      try {
        await socket.map(toIntList).pipe(iosink);
      } finally {
        iosink.close();
      }
    } finally {
      socket.destroy();
    }*/
  }

  List<int> toIntList(Uint8List source) {
    return List.from(source);
  }
}
