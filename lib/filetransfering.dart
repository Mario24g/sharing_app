import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:sharing_app/networking.dart';

class FileTransferManager {
  final int _port = 8890;
  ServerSocket? server;

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
    final ServerSocket server = await ServerSocket.bind('localhost', _port);
    print("Server started at ${server.address.address}:${server.port}");

    server.listen((client) async {
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
        "Connected to:"
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
