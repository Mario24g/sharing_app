// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeviceAdapter extends TypeAdapter<Device> {
  @override
  final int typeId = 1;

  @override
  Device read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Device(
      ip: fields[0] as String,
      name: fields[1] as String,
      devicePlatform: fields[2] as DevicePlatform,
    );
  }

  @override
  void write(BinaryWriter writer, Device obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.ip)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.devicePlatform)
      ..writeByte(3)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DevicePlatformAdapter extends TypeAdapter<DevicePlatform> {
  @override
  final int typeId = 2;

  @override
  DevicePlatform read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DevicePlatform.windows;
      case 1:
        return DevicePlatform.linux;
      case 2:
        return DevicePlatform.macos;
      case 3:
        return DevicePlatform.android;
      case 4:
        return DevicePlatform.ios;
      case 5:
        return DevicePlatform.unknown;
      default:
        return DevicePlatform.windows;
    }
  }

  @override
  void write(BinaryWriter writer, DevicePlatform obj) {
    switch (obj) {
      case DevicePlatform.windows:
        writer.writeByte(0);
        break;
      case DevicePlatform.linux:
        writer.writeByte(1);
        break;
      case DevicePlatform.macos:
        writer.writeByte(2);
        break;
      case DevicePlatform.android:
        writer.writeByte(3);
        break;
      case DevicePlatform.ios:
        writer.writeByte(4);
        break;
      case DevicePlatform.unknown:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevicePlatformAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
