// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_task_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadTaskModelAdapter extends TypeAdapter<DownloadTaskModel> {
  @override
  final typeId = 0;

  @override
  DownloadTaskModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadTaskModel(
      id: fields[0] as String,
      url: fields[1] as String,
      savePath: fields[2] as String,
      downloadedBytes: fields[3] == null ? 0 : (fields[3] as num).toInt(),
      totalBytes: fields[4] == null ? 0 : (fields[4] as num).toInt(),
      status: fields[5] == null ? 'pending' : fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadTaskModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.savePath)
      ..writeByte(3)
      ..write(obj.downloadedBytes)
      ..writeByte(4)
      ..write(obj.totalBytes)
      ..writeByte(5)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTaskModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
