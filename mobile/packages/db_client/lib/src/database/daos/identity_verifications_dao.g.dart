// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity_verifications_dao.dart';

// ignore_for_file: type=lint
mixin _$IdentityVerificationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $IdentityVerificationsTable get identityVerifications =>
      attachedDatabase.identityVerifications;
  IdentityVerificationsDaoManager get managers =>
      IdentityVerificationsDaoManager(this);
}

class IdentityVerificationsDaoManager {
  final _$IdentityVerificationsDaoMixin _db;
  IdentityVerificationsDaoManager(this._db);
  $$IdentityVerificationsTableTableManager get identityVerifications =>
      $$IdentityVerificationsTableTableManager(
        _db.attachedDatabase,
        _db.identityVerifications,
      );
}
