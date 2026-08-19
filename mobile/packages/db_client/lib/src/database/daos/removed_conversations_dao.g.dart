// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'removed_conversations_dao.dart';

// ignore_for_file: type=lint
mixin _$RemovedConversationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RemovedConversationsTable get removedConversations =>
      attachedDatabase.removedConversations;
  RemovedConversationsDaoManager get managers =>
      RemovedConversationsDaoManager(this);
}

class RemovedConversationsDaoManager {
  final _$RemovedConversationsDaoMixin _db;
  RemovedConversationsDaoManager(this._db);
  $$RemovedConversationsTableTableManager get removedConversations =>
      $$RemovedConversationsTableTableManager(
        _db.attachedDatabase,
        _db.removedConversations,
      );
}
