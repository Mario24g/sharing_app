import 'dart:io';
import 'dart:typed_data';

class FileTransferManager {
  int size = 0;
  void initialize() {
    _startServer();
    _startClient();
  }

  void _startServer() async {
    final ServerSocket server = await ServerSocket.bind('localhost', 8888);
    server.listen((client) async {
      await File('1.zip').openRead().pipe(client);
    });
  }

  void handleClient(Socket client) async {
    File file = File('1.zip');
    Uint8List bytes = await file.readAsBytesSync();
    print(
      "Connection from:"
      "${client.remoteAddress.address}:${client.remotePort}",
    );
    client.listen((Uint8List data) async {
      await Future.delayed(Duration(seconds: 1));
      final request = String.fromCharCodes(data);
      if (request == 'Send Data') {
        client.add(bytes);
      }
      client.close();
    });
  }

  void _startClient() async {
    final socket = await Socket.connect('localhost', 2714);
    print(
      "Connected to:"
      '${socket.remoteAddress.address}:${socket.remotePort}',
    );
    socket.write('Send Data');
    socket.listen((Uint8List data) async {
      await Future.delayed(Duration(seconds: 1));
      dataHandler(data);
      size = size + data.lengthInBytes;
      print(size);
      print("ok: data written");
    });
    await Future.delayed(Duration(seconds: 20));
    socket.close();
    socket.destroy();
  }

  BytesBuilder builder = BytesBuilder(copy: false);
  void dataHandler(Uint8List data) {
    builder.add(data);

    if (builder.length <= 1049497288) {
      // file size
      Uint8List dt = builder.toBytes();

      writeToFile(
        dt.buffer.asUint8List(0, dt.buffer.lengthInBytes),
        '1(recieved).zip',
      );
    }
  }

  Future<void> writeToFile(Uint8List data, String path) {
    // final buffer = data.buffer;
    return File(path).writeAsBytes(data);
  }

  void _openClient() async {
    final Socket socket = await Socket.connect('localhost', 2714);
    try {
      print(
        "Connected to:"
        '${socket.remoteAddress.address}:${socket.remotePort}',
      );
      socket.write('Send Data');

      var file = File('1_received.zip').openWrite();
      try {
        await socket.map(toIntList).pipe(file);
      } finally {
        file.close();
      }
    } finally {
      socket.destroy();
    }
  }

  List<int> toIntList(Uint8List source) {
    return List.from(source);
  }
}
