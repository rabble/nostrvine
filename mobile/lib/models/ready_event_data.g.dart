// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ready_event_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReadyEventDataAdapter extends TypeAdapter<ReadyEventData> {
  @override
  final int typeId = 3;

  @override
  ReadyEventData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadyEventData(
      publicId: fields[0] as String,
      secureUrl: fields[1] as String,
      contentSuggestion: fields[2] as String,
      tags: (fields[3] as List)
          .map((dynamic e) => (e as List).cast<String>())
          .toList(),
      metadata: (fields[4] as Map).cast<String, dynamic>(),
      processedAt: fields[5] as DateTime,
      originalUploadId: fields[6] as String,
      mimeType: fields[7] as String,
      fileSize: fields[8] as int?,
      thumbnailUrl: fields[9] as String?,
      width: fields[10] as int?,
      height: fields[11] as int?,
      duration: fields[12] as double?,
      hash: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadyEventData obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.publicId)
      ..writeByte(1)
      ..write(obj.secureUrl)
      ..writeByte(2)
      ..write(obj.contentSuggestion)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.metadata)
      ..writeByte(5)
      ..write(obj.processedAt)
      ..writeByte(6)
      ..write(obj.originalUploadId)
      ..writeByte(7)
      ..write(obj.mimeType)
      ..writeByte(8)
      ..write(obj.fileSize)
      ..writeByte(9)
      ..write(obj.thumbnailUrl)
      ..writeByte(10)
      ..write(obj.width)
      ..writeByte(11)
      ..write(obj.height)
      ..writeByte(12)
      ..write(obj.duration)
      ..writeByte(13)
      ..write(obj.hash);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadyEventDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
