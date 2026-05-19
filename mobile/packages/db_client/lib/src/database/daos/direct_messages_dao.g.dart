// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'direct_messages_dao.dart';

// ignore_for_file: type=lint
mixin _$DirectMessagesDaoMixin on DatabaseAccessor<AppDatabase> {
  $DirectMessagesTable get directMessages => attachedDatabase.directMessages;
  DirectMessagesDaoManager get managers => DirectMessagesDaoManager(this);
}

class DirectMessagesDaoManager {
  final _$DirectMessagesDaoMixin _db;
  DirectMessagesDaoManager(this._db);
  $$DirectMessagesTableTableManager get directMessages =>
      $$DirectMessagesTableTableManager(
        _db.attachedDatabase,
        _db.directMessages,
      );
}
