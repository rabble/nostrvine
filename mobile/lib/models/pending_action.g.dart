// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_action.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingActionAdapter extends TypeAdapter<PendingAction> {
  @override
  final typeId = 5;

  @override
  PendingAction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingAction(
      id: fields[0] as String,
      type: fields[1] as PendingActionType,
      targetId: fields[2] as String,
      createdAt: fields[6] as DateTime,
      status: fields[7] as PendingActionStatus,
      authorPubkey: fields[3] as String?,
      addressableId: fields[4] as String?,
      targetKind: (fields[5] as num?)?.toInt(),
      retryCount: fields[8] == null ? 0 : (fields[8] as num).toInt(),
      lastError: fields[9] as String?,
      lastAttemptAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PendingAction obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.targetId)
      ..writeByte(3)
      ..write(obj.authorPubkey)
      ..writeByte(4)
      ..write(obj.addressableId)
      ..writeByte(5)
      ..write(obj.targetKind)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.retryCount)
      ..writeByte(9)
      ..write(obj.lastError)
      ..writeByte(10)
      ..write(obj.lastAttemptAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PendingActionTypeAdapter extends TypeAdapter<PendingActionType> {
  @override
  final typeId = 3;

  @override
  PendingActionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PendingActionType.like;
      case 1:
        return PendingActionType.unlike;
      case 2:
        return PendingActionType.repost;
      case 3:
        return PendingActionType.unrepost;
      case 4:
        return PendingActionType.follow;
      case 5:
        return PendingActionType.unfollow;
      default:
        return PendingActionType.like;
    }
  }

  @override
  void write(BinaryWriter writer, PendingActionType obj) {
    switch (obj) {
      case PendingActionType.like:
        writer.writeByte(0);
      case PendingActionType.unlike:
        writer.writeByte(1);
      case PendingActionType.repost:
        writer.writeByte(2);
      case PendingActionType.unrepost:
        writer.writeByte(3);
      case PendingActionType.follow:
        writer.writeByte(4);
      case PendingActionType.unfollow:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingActionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PendingActionStatusAdapter extends TypeAdapter<PendingActionStatus> {
  @override
  final typeId = 4;

  @override
  PendingActionStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PendingActionStatus.pending;
      case 1:
        return PendingActionStatus.syncing;
      case 2:
        return PendingActionStatus.completed;
      case 3:
        return PendingActionStatus.failed;
      default:
        return PendingActionStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, PendingActionStatus obj) {
    switch (obj) {
      case PendingActionStatus.pending:
        writer.writeByte(0);
      case PendingActionStatus.syncing:
        writer.writeByte(1);
      case PendingActionStatus.completed:
        writer.writeByte(2);
      case PendingActionStatus.failed:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingActionStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
