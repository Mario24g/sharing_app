import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:path/path.dart' as path;
import 'package:blitzshare/main.dart';
import 'package:blitzshare/model/device.dart';

class TransferProtocol {
  static const int METADATA_TYPE = 1;
  static const int FILE_CHUNK_TYPE = 2;
  static const int TRANSFER_COMPLETE_TYPE = 3;
  static const int ERROR_TYPE = 4;
  static const int ACK_TYPE = 5;

  static const int CHUNK_SIZE = 64 * 1024;
  static const int HEADER_SIZE = 16;
}

class TransferMessage {
  final int type;
  final Uint8List data;

  TransferMessage(this.type, this.data);

  Uint8List toBytes() {
    final ByteData header = ByteData(TransferProtocol.HEADER_SIZE);
    header.setInt64(0, type, Endian.big);
    header.setInt64(8, data.length, Endian.big);

    final Uint8List result = Uint8List(TransferProtocol.HEADER_SIZE + data.length);
    result.setRange(0, TransferProtocol.HEADER_SIZE, header.buffer.asUint8List());
    result.setRange(TransferProtocol.HEADER_SIZE, result.length, data);

    return result;
  }

  static TransferMessage? fromBytes(Uint8List bytes) {
    if (bytes.length < TransferProtocol.HEADER_SIZE) return null;

    final ByteData header = ByteData.sublistView(bytes, 0, TransferProtocol.HEADER_SIZE);
    final int type = header.getInt64(0, Endian.big);
    final int dataLength = header.getInt64(8, Endian.big);

    if (bytes.length < TransferProtocol.HEADER_SIZE + dataLength) return null;

    final Uint8List data = bytes.sublist(TransferProtocol.HEADER_SIZE, TransferProtocol.HEADER_SIZE + dataLength);
    return TransferMessage(type, data);
  }
}

class FileMetadata {
  final String filename;
  final int fileSize;
  final int totalChunks;

  FileMetadata({required this.filename, required this.fileSize, required this.totalChunks});

  Map<String, dynamic> toJson() => {'filename': filename, 'fileSize': fileSize, 'totalChunks': totalChunks};

  factory FileMetadata.fromJson(Map<String, dynamic> json) =>
      FileMetadata(filename: json['filename'], fileSize: json['fileSize'], totalChunks: json['totalChunks']);
}

class FileChunk {
  final int chunkIndex;
  final Uint8List data;
  final String filename;

  FileChunk({required this.chunkIndex, required this.data, required this.filename});

  Map<String, dynamic> toJson() => {'chunkIndex': chunkIndex, 'filename': filename, 'dataLength': data.length};

  Uint8List toBytes() {
    final String jsonStr = jsonEncode(toJson());
    final List<int> jsonBytes = utf8.encode(jsonStr);
    final ByteData header = ByteData(8);
    header.setInt64(0, jsonBytes.length, Endian.big);

    final Uint8List result = Uint8List(8 + jsonBytes.length + data.length);
    result.setRange(0, 8, header.buffer.asUint8List());
    result.setRange(8, 8 + jsonBytes.length, jsonBytes);
    result.setRange(8 + jsonBytes.length, result.length, data);

    return result;
  }

  static FileChunk? fromBytes(Uint8List bytes) {
    if (bytes.length < 8) return null;

    final ByteData header = ByteData.sublistView(bytes, 0, 8);
    final int jsonLength = header.getInt64(0, Endian.big);

    if (bytes.length < 8 + jsonLength) return null;

    final String jsonStr = utf8.decode(bytes.sublist(8, 8 + jsonLength));
    final Map<String, dynamic> json = jsonDecode(jsonStr);
    final Uint8List data = bytes.sublist(8 + jsonLength);

    return FileChunk(chunkIndex: json['chunkIndex'], filename: json['filename'], data: data);
  }
}

class TcpFileSender {
  final int port;

  TcpFileSender({required this.port});

  Future createTransferTask(
    List<Device> selectedDevices,
    List<File> selectedFiles,
    void Function(String message)? onTransferComplete,
    void Function(double progress)? onProgressUpdate,
    void Function(String statusMessage)? onStatusUpdate,
  ) async {
    final int totalFiles = selectedDevices.length * selectedFiles.length;
    int completedFiles = 0;

    for (final Device device in selectedDevices) {
      for (final File file in selectedFiles) {
        onStatusUpdate?.call("Transferring ${path.basename(file.path)} to ${device.name}");

        await sendFile(device.ip, file, (progress) {
          onProgressUpdate?.call(progress);
          if (progress >= 1.0) {
            completedFiles++;
            onStatusUpdate?.call("Transferred ${path.basename(file.path)} to ${device.name} ($completedFiles/$totalFiles)");
          }
        });
      }
    }

    onTransferComplete?.call("Transferred ${selectedFiles.length} file(s) to ${selectedDevices.length} device(s)");
  }

  Future sendFile(String targetIp, File file, void Function(double progress)? onProgress) async {
    Socket? socket;
    SocketMessageHandler? messageHandler;

    try {
      socket = await Socket.connect(targetIp, port).timeout(Duration(seconds: 10));
      messageHandler = SocketMessageHandler(socket);

      final int fileSize = await file.length();
      final int totalChunks = (fileSize / TransferProtocol.CHUNK_SIZE).ceil();
      final FileMetadata metadata = FileMetadata(filename: path.basename(file.path), fileSize: fileSize, totalChunks: totalChunks);

      final TransferMessage metadataMessage = TransferMessage(TransferProtocol.METADATA_TYPE, Uint8List.fromList(utf8.encode(jsonEncode(metadata.toJson()))));
      socket.add(metadataMessage.toBytes());

      await messageHandler.waitForMessage(TransferProtocol.ACK_TYPE).timeout(Duration(seconds: 30));

      final RandomAccessFile raf = await file.open();
      int bytesSent = 0;

      try {
        for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
          final int chunkSize = (chunkIndex == totalChunks - 1) ? fileSize - (chunkIndex * TransferProtocol.CHUNK_SIZE) : TransferProtocol.CHUNK_SIZE;

          final Uint8List chunkData = await raf.read(chunkSize);
          final FileChunk chunk = FileChunk(chunkIndex: chunkIndex, data: chunkData, filename: metadata.filename);

          final TransferMessage chunkMessage = TransferMessage(TransferProtocol.FILE_CHUNK_TYPE, chunk.toBytes());

          socket.add(chunkMessage.toBytes());

          // Wait for chunk acknowledgment with timeout
          await messageHandler.waitForMessage(TransferProtocol.ACK_TYPE).timeout(Duration(seconds: 30));

          bytesSent += chunkSize;
          final double progress = bytesSent / fileSize;
          onProgress?.call(progress);
        }
      } finally {
        await raf.close();
      }

      final TransferMessage completeMessage = TransferMessage(TransferProtocol.TRANSFER_COMPLETE_TYPE, Uint8List.fromList(utf8.encode(metadata.filename)));
      socket.add(completeMessage.toBytes());
    } catch (e) {
      print("Error sending file: $e");
      if (socket != null) {
        try {
          final TransferMessage errorMessage = TransferMessage(TransferProtocol.ERROR_TYPE, Uint8List.fromList(utf8.encode(e.toString())));
          socket.add(errorMessage.toBytes());
        } catch (e) {
          print("Error sending message: $e");
        }
      }
      rethrow;
    } finally {
      await messageHandler?.dispose();
      await socket?.close();
    }
  }
}

class SocketMessageHandler {
  final Socket _socket;
  late final StreamController<TransferMessage> _messageController;
  final List<int> _buffer = [];
  StreamSubscription? _socketSubscription;
  bool _disposed = false;

  SocketMessageHandler(this._socket) {
    _messageController = StreamController<TransferMessage>.broadcast();
    _initializeListener();
  }

  void _initializeListener() {
    _socketSubscription = _socket.listen(
      (List<int> data) {
        if (!_disposed) {
          _buffer.addAll(data);
          _processBuffer();
        }
      },
      onError: (error) {
        if (!_disposed) {
          _messageController.addError(error);
        }
      },
      onDone: () {
        if (!_disposed) {
          _messageController.close();
        }
      },
    );
  }

  void _processBuffer() {
    while (_buffer.length >= TransferProtocol.HEADER_SIZE && !_disposed) {
      final ByteData header = ByteData.sublistView(Uint8List.fromList(_buffer), 0, TransferProtocol.HEADER_SIZE);
      final int dataLength = header.getInt64(8, Endian.big);
      final int totalMessageSize = TransferProtocol.HEADER_SIZE + dataLength;

      //Check if the message is complete
      if (_buffer.length >= totalMessageSize) {
        final Uint8List messageBytes = Uint8List.fromList(_buffer.take(totalMessageSize).toList());
        final TransferMessage? message = TransferMessage.fromBytes(messageBytes);

        if (message != null && !_disposed) {
          _messageController.add(message);
        }

        //Remove processed message
        _buffer.removeRange(0, totalMessageSize);
      } else {
        break;
      }
    }
  }

  Future<TransferMessage> waitForMessage(int expectedType) async {
    if (_disposed) {
      throw Exception("MessageHandler disposed");
    }

    await for (TransferMessage message in _messageController.stream) {
      if (message.type == expectedType) {
        return message;
      }
    }
    throw Exception("Connection closed while waiting for message type: $expectedType");
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _socketSubscription?.cancel();
    await _messageController.close();
  }
}

class TcpFileReceiver {
  final int port;
  final AppState appState;
  final void Function(String message, Device senderDevice, List<File> files)? onFileReceived;

  ServerSocket? _serverSocket;
  final Map<String, FileTransferSession> _activeSessions = {};

  TcpFileReceiver({required this.port, required this.appState, required this.onFileReceived});

  Future startReceiverServer() async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    print("TCP Server running on ${_serverSocket!.address.address}:${_serverSocket!.port}");

    await for (Socket clientSocket in _serverSocket!) {
      _handleClient(clientSocket);
    }
  }

  void _handleClient(Socket clientSocket) async {
    final String clientIp = clientSocket.remoteAddress.address;
    final Device senderDevice = appState.devices.firstWhere(
      (device) => device.ip == clientIp,
      orElse: () => Device(ip: clientIp, name: "Unknown Device", devicePlatform: DevicePlatform.unknown),
    );

    SocketMessageHandler? messageHandler;

    try {
      messageHandler = SocketMessageHandler(clientSocket);

      // Process messages
      await for (TransferMessage message in messageHandler._messageController.stream) {
        await _processMessage(message, clientSocket, clientIp, senderDevice);
      }
    } catch (e) {
      print("Error handling client $clientIp: $e");
    } finally {
      _activeSessions.remove(clientIp);
      await messageHandler?.dispose();
      await clientSocket.close();
    }
  }

  Future _processMessage(TransferMessage message, Socket clientSocket, String clientIp, Device senderDevice) async {
    try {
      switch (message.type) {
        case TransferProtocol.METADATA_TYPE:
          await _handleMetadata(message, clientSocket, clientIp);
          break;
        case TransferProtocol.FILE_CHUNK_TYPE:
          await _handleFileChunk(message, clientSocket, clientIp, senderDevice);
          break;
        case TransferProtocol.TRANSFER_COMPLETE_TYPE:
          await _handleTransferComplete(message, clientIp, senderDevice);
          break;
        case TransferProtocol.ERROR_TYPE:
          print("Received error from client: ${utf8.decode(message.data)}");
          break;
      }
    } catch (e) {
      print("Error processing message type ${message.type}: $e");
      try {
        final TransferMessage errorAck = TransferMessage(TransferProtocol.ERROR_TYPE, Uint8List.fromList(utf8.encode(e.toString())));
        clientSocket.add(errorAck.toBytes());
      } catch (e) {
        print("Error sending response: $e");
      }
    }
  }

  Future _handleMetadata(TransferMessage message, Socket clientSocket, String clientIp) async {
    try {
      final Map<String, dynamic> metadata = jsonDecode(utf8.decode(message.data));
      final FileMetadata fileMetadata = FileMetadata.fromJson(metadata);

      _activeSessions[clientIp] = FileTransferSession(metadata: fileMetadata, receivedChunks: {}, tempFile: await _createTempFile(fileMetadata.filename));

      final TransferMessage ack = TransferMessage(TransferProtocol.ACK_TYPE, Uint8List(0));
      clientSocket.add(ack.toBytes());
    } catch (e) {
      print("Error handling metadata: $e");
      rethrow;
    }
  }

  Future _handleFileChunk(TransferMessage message, Socket clientSocket, String clientIp, Device senderDevice) async {
    final FileTransferSession? session = _activeSessions[clientIp];
    if (session == null) {
      throw Exception("No active session for client $clientIp");
    }

    try {
      final FileChunk? chunk = FileChunk.fromBytes(message.data);
      if (chunk == null) {
        throw Exception("Failed to parse file chunk");
      }

      //Write each chunk to a temp file
      final RandomAccessFile raf = await session.tempFile.open(mode: FileMode.writeOnlyAppend);
      try {
        await raf.setPosition(chunk.chunkIndex * TransferProtocol.CHUNK_SIZE);
        await raf.writeFrom(chunk.data);
      } finally {
        await raf.close();
      }

      session.receivedChunks[chunk.chunkIndex] = true;

      final TransferMessage ack = TransferMessage(TransferProtocol.ACK_TYPE, Uint8List(0));
      clientSocket.add(ack.toBytes());

      //Check if all chunks were received
      if (session.receivedChunks.length == session.metadata.totalChunks) {
        await _finalizeFile(session, senderDevice);
      }
    } catch (e) {
      print('Error handling file chunk: $e');
      rethrow;
    }
  }

  Future _handleTransferComplete(TransferMessage message, String clientIp, Device senderDevice) async {
    final String filename = utf8.decode(message.data);
    final FileTransferSession? session = _activeSessions[clientIp];

    if (session != null) {
      onFileReceived?.call("File $filename received from $clientIp", senderDevice, [session.tempFile]);
    }

    _activeSessions.remove(clientIp);
  }

  Future<File> _createTempFile(String filename) async {
    final Directory tempDir = await Directory.systemTemp.createTemp();
    return File('${tempDir.path}/$filename');
  }

  Future<void> _finalizeFile(FileTransferSession session, Device senderDevice) async {
    try {
      final bool? success = await copyFileIntoDownloadFolder(session.tempFile.path, session.metadata.filename);

      if (success!) {
        print("Failed to move file to downloads folder");
      }
    } catch (e) {
      print("Error finalizing file: $e");
    }
  }

  Future stopServer() async {
    await _serverSocket?.close();
    _serverSocket = null;
  }
}

class FileTransferSession {
  final FileMetadata metadata;
  final Map<int, bool> receivedChunks;
  final File tempFile;

  FileTransferSession({required this.metadata, required this.receivedChunks, required this.tempFile});
}
