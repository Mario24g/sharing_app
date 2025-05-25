// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'historyentry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HistoryEntryAdapter extends TypeAdapter<HistoryEntry> {
  @override
  final int typeId = 0;

  @override
  HistoryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HistoryEntry(
      isUpload: fields[0] as bool,
      filePaths: (fields[1] as List).cast<String>(),
      targetDevices: (fields[2] as List?)?.cast<Device>(),
      senderDevice: fields[3] as Device?,
    );
  }

  @override
  void write(BinaryWriter writer, HistoryEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.isUpload)
      ..writeByte(1)
      ..write(obj.filePaths)
      ..writeByte(2)
      ..write(obj.targetDevices)
      ..writeByte(3)
      ..write(obj.senderDevice)
      ..writeByte(4)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
