// ABOUTME: Test helper that captures TextInput method-channel calls
// ABOUTME: so tests can assert finishAutofillContext fired with shouldSave=true.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures method calls made on [SystemChannels.textInput] during a test.
///
/// Install at the start of a test with [install], then read [calls] or
/// [didFinishAutofillContext] to assert behaviour. The handler is torn
/// down automatically by Flutter's test binding at the end of the test.
class AutofillContextRecorder {
  AutofillContextRecorder._();

  /// Installs the mock handler and returns the recorder.
  static AutofillContextRecorder install() {
    final recorder = AutofillContextRecorder._();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.textInput, (call) async {
          recorder._calls.add(call);
          return null;
        });
    return recorder;
  }

  final List<MethodCall> _calls = [];

  /// Every method call the text-input channel received.
  List<MethodCall> get calls => List.unmodifiable(_calls);

  /// True when `TextInput.finishAutofillContext` was called with
  /// `shouldSave: true` (the default, and the only value we ever send).
  bool get didFinishAutofillContext => _calls.any(
    (call) =>
        call.method == 'TextInput.finishAutofillContext' &&
        call.arguments == true,
  );
}
