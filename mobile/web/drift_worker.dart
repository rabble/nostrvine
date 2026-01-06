// ABOUTME: Drift web worker for WASM-based SQLite database
// ABOUTME: This worker hosts the database in a background thread for better
// ABOUTME: performance and enables sharing between browser tabs.
//
// To compile this worker, run:
//   dart compile js -O4 -o web/drift_worker.js web/drift_worker.dart

import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
