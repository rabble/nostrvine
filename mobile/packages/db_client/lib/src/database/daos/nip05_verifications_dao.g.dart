// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nip05_verifications_dao.dart';

// ignore_for_file: type=lint
mixin _$Nip05VerificationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $Nip05VerificationsTable get nip05Verifications =>
      attachedDatabase.nip05Verifications;
  Nip05VerificationsDaoManager get managers =>
      Nip05VerificationsDaoManager(this);
}

class Nip05VerificationsDaoManager {
  final _$Nip05VerificationsDaoMixin _db;
  Nip05VerificationsDaoManager(this._db);
  $$Nip05VerificationsTableTableManager get nip05Verifications =>
      $$Nip05VerificationsTableTableManager(
        _db.attachedDatabase,
        _db.nip05Verifications,
      );
}
