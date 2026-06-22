// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processed_gift_wraps_dao.dart';

// ignore_for_file: type=lint
mixin _$ProcessedGiftWrapsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProcessedGiftWrapsTable get processedGiftWraps =>
      attachedDatabase.processedGiftWraps;
  ProcessedGiftWrapsDaoManager get managers =>
      ProcessedGiftWrapsDaoManager(this);
}

class ProcessedGiftWrapsDaoManager {
  final _$ProcessedGiftWrapsDaoMixin _db;
  ProcessedGiftWrapsDaoManager(this._db);
  $$ProcessedGiftWrapsTableTableManager get processedGiftWraps =>
      $$ProcessedGiftWrapsTableTableManager(
        _db.attachedDatabase,
        _db.processedGiftWraps,
      );
}
