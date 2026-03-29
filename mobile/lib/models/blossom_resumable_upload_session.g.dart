// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blossom_resumable_upload_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BlossomResumableUploadSessionAdapter
    extends TypeAdapter<BlossomResumableUploadSession> {
  @override
  final typeId = 3;

  @override
  BlossomResumableUploadSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BlossomResumableUploadSession(
      uploadId: fields[0] as String,
      uploadUrl: fields[1] as String,
      chunkSize: (fields[2] as num).toInt(),
      nextOffset: (fields[3] as num).toInt(),
      expiresAt: fields[4] as DateTime?,
      requiredHeaders: (fields[5] as Map?)?.cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, BlossomResumableUploadSession obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.uploadId)
      ..writeByte(1)
      ..write(obj.uploadUrl)
      ..writeByte(2)
      ..write(obj.chunkSize)
      ..writeByte(3)
      ..write(obj.nextOffset)
      ..writeByte(4)
      ..write(obj.expiresAt)
      ..writeByte(5)
      ..write(obj.requiredHeaders);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlossomResumableUploadSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
