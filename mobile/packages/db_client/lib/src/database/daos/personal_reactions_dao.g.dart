// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_reactions_dao.dart';

// ignore_for_file: type=lint
mixin _$PersonalReactionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PersonalReactionsTable get personalReactions =>
      attachedDatabase.personalReactions;
  PersonalReactionsDaoManager get managers => PersonalReactionsDaoManager(this);
}

class PersonalReactionsDaoManager {
  final _$PersonalReactionsDaoMixin _db;
  PersonalReactionsDaoManager(this._db);
  $$PersonalReactionsTableTableManager get personalReactions =>
      $$PersonalReactionsTableTableManager(
        _db.attachedDatabase,
        _db.personalReactions,
      );
}
