import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web index bootstraps sql.js for Drift web storage', () {
    final contents = File('web/index.html').readAsStringSync();

    expect(contents, contains('sql-wasm.js'));
    expect(contents, contains('initSqlJs'));
    expect(contents, contains('locateFile'));
    expect(contents, contains('pointer-events: none'));
  });
}
