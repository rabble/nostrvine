// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_upload.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingUploadAdapter extends TypeAdapter<PendingUpload> {
  @override
  final int typeId = 2;

  @override
  PendingUpload read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingUpload(
      id: fields[0] as String,
      localVideoPath: fields[1] as String,
      nostrPubkey: fields[2] as String,
      status: fields[3] as UploadStatus,
      createdAt: fields[4] as DateTime,
      cloudinaryPublicId: fields[5] as String?,
      videoId: fields[15] as String?,
      cdnUrl: fields[16] as String?,
      errorMessage: fields[6] as String?,
      uploadProgress: fields[7] as double?,
      thumbnailPath: fields[8] as String?,
      title: fields[9] as String?,
      description: fields[10] as String?,
      hashtags: (fields[11] as List?)?.cast<String>(),
      nostrEventId: fields[12] as String?,
      completedAt: fields[13] as DateTime?,
      retryCount: fields[14] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, PendingUpload obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.localVideoPath)
      ..writeByte(2)
      ..write(obj.nostrPubkey)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.cloudinaryPublicId)
      ..writeByte(15)
      ..write(obj.videoId)
      ..writeByte(16)
      ..write(obj.cdnUrl)
      ..writeByte(6)
      ..write(obj.errorMessage)
      ..writeByte(7)
      ..write(obj.uploadProgress)
      ..writeByte(8)
      ..write(obj.thumbnailPath)
      ..writeByte(9)
      ..write(obj.title)
      ..writeByte(10)
      ..write(obj.description)
      ..writeByte(11)
      ..write(obj.hashtags)
      ..writeByte(12)
      ..write(obj.nostrEventId)
      ..writeByte(13)
      ..write(obj.completedAt)
      ..writeByte(14)
      ..write(obj.retryCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingUploadAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UploadStatusAdapter extends TypeAdapter<UploadStatus> {
  @override
  final int typeId = 1;

  @override
  UploadStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UploadStatus.pending;
      case 1:
        return UploadStatus.uploading;
      case 2:
        return UploadStatus.retrying;
      case 3:
        return UploadStatus.processing;
      case 4:
        return UploadStatus.readyToPublish;
      case 5:
        return UploadStatus.published;
      case 6:
        return UploadStatus.failed;
      case 7:
        return UploadStatus.paused;
      default:
        return UploadStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, UploadStatus obj) {
    switch (obj) {
      case UploadStatus.pending:
        writer.writeByte(0);
        break;
      case UploadStatus.uploading:
        writer.writeByte(1);
        break;
      case UploadStatus.retrying:
        writer.writeByte(2);
        break;
      case UploadStatus.processing:
        writer.writeByte(3);
        break;
      case UploadStatus.readyToPublish:
        writer.writeByte(4);
        break;
      case UploadStatus.published:
        writer.writeByte(5);
        break;
      case UploadStatus.failed:
        writer.writeByte(6);
        break;
      case UploadStatus.paused:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
