import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;

void main() {
  group('handleKnownFrameworkError', () {
    test('clears keyboard state for known hardware keyboard assertions', () {
      var clearedKeyboardState = false;
      String? warningMessage;

      final handled = app.handleKnownFrameworkError(
        FlutterErrorDetails(
          exception: AssertionError(
            'HardwareKeyboard KeyDownEvent duplicate pressed key state',
          ),
        ),
        logWarning: (message) => warningMessage = message,
        clearKeyboardState: () => clearedKeyboardState = true,
      );

      expect(handled, isTrue);
      expect(clearedKeyboardState, isTrue);
      expect(
        warningMessage,
        contains('Known Flutter framework keyboard issue'),
      );
    });

    test('ignores unrelated framework errors', () {
      var clearedKeyboardState = false;
      var loggedWarning = false;

      final handled = app.handleKnownFrameworkError(
        FlutterErrorDetails(exception: StateError('some other failure')),
        logWarning: (_) => loggedWarning = true,
        clearKeyboardState: () => clearedKeyboardState = true,
      );

      expect(handled, isFalse);
      expect(clearedKeyboardState, isFalse);
      expect(loggedWarning, isFalse);
    });
  });
}
