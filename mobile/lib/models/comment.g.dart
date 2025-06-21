// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CommentAdapter extends TypeAdapter<Comment> {
  @override
  final int typeId = 3;

  @override
  Comment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Comment(
      id: fields[0] as String,
      content: fields[1] as String,
      authorPubkey: fields[2] as String,
      createdAt: fields[3] as DateTime,
      rootEventId: fields[4] as String,
      replyToEventId: fields[5] as String?,
      rootAuthorPubkey: fields[6] as String,
      replyToAuthorPubkey: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Comment obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.authorPubkey)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.rootEventId)
      ..writeByte(5)
      ..write(obj.replyToEventId)
      ..writeByte(6)
      ..write(obj.rootAuthorPubkey)
      ..writeByte(7)
      ..write(obj.replyToAuthorPubkey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
