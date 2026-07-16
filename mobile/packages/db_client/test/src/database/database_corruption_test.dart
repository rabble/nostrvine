import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

/// A query executor whose statements all fail with [error].
///
/// Real corruption cannot be provoked from a unit test, so this stands in for
/// the failing native connection: the interceptor's whole job is classifying
/// what comes back out of the executor, which is exactly what this fakes.
class _FailingExecutor extends QueryExecutor {
  _FailingExecutor(this.error);

  final Object error;

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  TransactionExecutor beginTransaction() => throw UnimplementedError();

  @override
  QueryExecutor beginExclusive() => this;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => Future.error(error);

  @override
  Future<void> runBatched(BatchedStatements statements) => Future.error(error);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      Future.error(error);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      Future.error(error);

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      Future.error(error);

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) => Future.error(error);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      Future.error(error);

  @override
  Future<void> close() async {}
}

/// The error the reported user saw: a `SqliteException(11)` from the d-tag
/// lookup, forwarded verbatim by `DriftRemoteException.toString()` because the
/// database runs on a background isolate.
const _corruptionError =
    'SqliteException(11): while selecting from statement, database disk image '
    'is malformed, database disk image is malformed (code 11)';

void main() {
  group('indicatesDatabaseCorruption', () {
    test('recognises SQLITE_CORRUPT', () {
      expect(indicatesDatabaseCorruption(Exception(_corruptionError)), isTrue);
    });

    test('recognises the SQLITE_CORRUPT_INDEX extended code', () {
      expect(
        indicatesDatabaseCorruption(
          Exception('SqliteException(779): database disk image is malformed'),
        ),
        isTrue,
      );
    });

    test('recognises SQLITE_NOTADB', () {
      expect(
        indicatesDatabaseCorruption(
          Exception('SqliteException(26): file is not a database'),
        ),
        isTrue,
      );
    });

    test('does not fire on an ordinary query failure', () {
      expect(
        indicatesDatabaseCorruption(
          Exception('SqliteException(1): no such table: event'),
        ),
        isFalse,
      );
    });

    test('ignores the corruption signature quoted in bound parameters', () {
      // Anyone can publish a Nostr event whose content quotes SQLite's
      // corruption message. `SqliteException.toString()` prints the bound
      // parameters, so classifying the whole string would let that content
      // schedule a salvage of a perfectly healthy database.
      expect(
        indicatesDatabaseCorruption(
          Exception(
            'SqliteException(19): UNIQUE constraint failed: event.id\n'
            '  Causing statement: INSERT INTO event (id, content) VALUES '
            '(?, ?), parameters: abc123, database disk image is malformed',
          ),
        ),
        isFalse,
      );
    });

    test('ignores a statement that merely selects on the signature', () {
      expect(
        indicatesDatabaseCorruption(
          Exception(
            'SqliteException(5): database is locked\n'
            '  Causing statement: SELECT * FROM event WHERE content = ?, '
            'parameters: file is not a database',
          ),
        ),
        isFalse,
      );
    });

    test('ignores a result code quoted inside bound parameters', () {
      // Pasting a SQLite error into a note is exactly the kind of thing people
      // post. Classifying anything below the header would let that text drive
      // a salvage from an unrelated failure that merely bound it.
      expect(
        indicatesDatabaseCorruption(
          Exception(
            'DriftWrappedException: could not insert event\n'
            '  Causing statement: INSERT INTO event (content) VALUES (?), '
            'parameters: SqliteException(11): database disk image is malformed',
          ),
        ),
        isFalse,
      );
    });

    test('does not fire on an error carrying no SQLite result code', () {
      expect(
        indicatesDatabaseCorruption(
          Exception('database disk image is malformed'),
        ),
        isFalse,
      );
    });
  });

  group(DatabaseCorruptionInterceptor, () {
    test('reports corruption surfacing on a select', () async {
      final reported = <Object>[];
      final executor = reportCorruptionFrom(
        _FailingExecutor(Exception(_corruptionError)),
        (error, _) => reported.add(error),
      );

      await expectLater(
        executor.runSelect('SELECT * FROM event', const []),
        throwsA(isA<Exception>()),
      );
      expect(reported, hasLength(1));
    });

    test('rethrows the original error unchanged', () async {
      final original = Exception(_corruptionError);
      final executor = reportCorruptionFrom(
        _FailingExecutor(original),
        (_, _) {},
      );

      await expectLater(
        executor.runSelect('SELECT * FROM event', const []),
        throwsA(same(original)),
      );
    });

    test('stays silent on an ordinary query failure', () async {
      final reported = <Object>[];
      final executor = reportCorruptionFrom(
        _FailingExecutor(Exception('SqliteException(1): no such table')),
        (error, _) => reported.add(error),
      );

      await expectLater(
        executor.runSelect('SELECT * FROM nope', const []),
        throwsA(isA<Exception>()),
      );
      expect(reported, isEmpty);
    });

    test('reports corruption surfacing on writes and the lazy open', () async {
      // A corrupt page can be reached by any statement, not just the d-tag
      // lookup that surfaced it in the field.
      final calls = <String, int>{};
      Future<void> expectReports(
        String label,
        Future<void> Function(QueryExecutor executor) run,
      ) async {
        final executor = reportCorruptionFrom(
          _FailingExecutor(Exception(_corruptionError)),
          (_, _) => calls[label] = (calls[label] ?? 0) + 1,
        );
        await expectLater(run(executor), throwsA(isA<Exception>()));
      }

      await expectReports(
        'insert',
        (e) => e.runInsert('INSERT INTO event VALUES (?)', const [1]),
      );
      await expectReports(
        'update',
        (e) => e.runUpdate('UPDATE event SET kind = ?', const [1]),
      );
      await expectReports(
        'delete',
        (e) => e.runDelete('DELETE FROM event', const []),
      );
      await expectReports('custom', (e) => e.runCustom('PRAGMA foo'));
      await expectReports(
        'ensureOpen',
        (e) => e.ensureOpen(_NoopUser()),
      );
      // Bulk ingestion goes through batch(), so a corrupt page first reached by
      // a batched write must report too. Without the override drift's default
      // forwards it silently and the next launch never salvages.
      await expectReports(
        'batched',
        (e) => e.runBatched(
          BatchedStatements(const ['INSERT INTO event VALUES (?)'], const []),
        ),
      );

      expect(
        calls,
        equals({
          'insert': 1,
          'update': 1,
          'delete': 1,
          'custom': 1,
          'ensureOpen': 1,
          'batched': 1,
        }),
      );
    });
  });
}

class _NoopUser extends QueryExecutorUser {
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}

  @override
  int get schemaVersion => 1;
}
