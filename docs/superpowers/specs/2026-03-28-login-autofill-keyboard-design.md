# Login Autofill And Keyboard Recovery Design

## Summary

Fix the desktop sign-in regressions by treating them as two narrowly scoped problems:

1. The login-options screen should use the same autofill structure as the other auth forms so password managers can recognize the email/password pair.
2. When Flutter throws the known `HardwareKeyboard` duplicate key assertion after logout/resume flows, the app should recover by clearing keyboard state instead of only logging and ignoring the exception.

## Scope

- Update the login screen autofill container to match the working auth pattern already used elsewhere in the app.
- Add regression coverage for the login screen widget tree and the keyboard recovery handler.
- Keep the existing sign-in UX and business logic unchanged.

## Files

- Modify `mobile/lib/screens/auth/login_options_screen.dart` to wrap the sign-in fields with `Form` inside the existing `AutofillGroup`.
- Modify `mobile/lib/main.dart` to reset Flutter keyboard state when the known framework assertion is detected.
- Modify `mobile/test/screens/auth/login_options_screen_test.dart` to cover the autofill form structure.
- Add `mobile/test/main_keyboard_error_handler_test.dart` to cover the keyboard recovery path in a focused way.

## Risks

- `HardwareKeyboard.clearState()` is a Flutter testing API, so production use should stay tightly scoped to the known assertion path and be documented in code.
- The login screen test should verify structure without over-coupling to visual layout.

## Verification

- Run the login screen widget test file.
- Run the new keyboard error handler test file.
- If both are green, optionally rerun the touched auth/widget tests if the diff grows.
