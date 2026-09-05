// ABOUTME: Pins the divine_ui semantic-label omission detector semantics.
// ABOUTME: Covers conditional controls and every supported invocation shape.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/divine_ui_semantic_label_detector.dart';

void main() {
  group('divine_ui_semantic_label_detector', () {
    late Directory temporaryDirectory;

    List<SemanticLabelOmission> scan(String source) {
      File('${temporaryDirectory.path}/subject.dart').writeAsStringSync(source);
      return findSemanticLabelOmissions(
        temporaryDirectory,
        pathPrefix: temporaryDirectory.path,
      );
    }

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync(
        'divine_ui_semantic_labels_',
      );
    });

    tearDown(() => temporaryDirectory.deleteSync(recursive: true));

    test('counts both labels on an obscured auth field', () {
      final omissions = scan('''
void build() {
  DivineAuthTextField(obscureText: true);
}
''');

      expect(omissions.map((omission) => omission.argument), [
        'hidePasswordSemanticLabel',
        'showPasswordSemanticLabel',
      ]);
      expect(omissions.map((omission) => omission.api).toSet(), {
        'DivineAuthTextField',
      });
      expect(omissions.map((omission) => omission.line).toSet(), {2});
    });

    test('does not count a non-password auth field', () {
      final omissions = scan('''
void build() {
  DivineAuthTextField();
  DivineAuthTextField(obscureText: false);
}
''');

      expect(omissions, isEmpty);
    });

    test('treats a dynamic obscureText expression as potentially visible', () {
      final omissions = scan('''
void build(bool obscured) {
  DivineAuthTextField(obscureText: obscured);
}
''');

      expect(omissions, hasLength(2));
    });

    test('reports only the omitted auth label', () {
      final omissions = scan('''
void build() {
  DivineAuthTextField(
    obscureText: true,
    showPasswordSemanticLabel: strings.showPassword,
  );
}
''');

      expect(omissions, hasLength(1));
      expect(omissions.single.argument, 'hidePasswordSemanticLabel');
    });

    test('supports const and import-prefixed constructors', () {
      // `const ui.X(...)` parses as an InstanceCreationExpression whose type
      // carries an import prefix; `ui.X(...)` without const is a
      // MethodInvocation. Both must resolve to the same API name.
      final omissions = scan('''
void build() {
  const DivineAuthTextField(obscureText: true);
  ui.DivineAuthTextField(obscureText: true);
  const ui.DivineAuthTextField(obscureText: true);
}
''');

      expect(omissions, hasLength(6));
    });

    test('counts constructor and static VineBottomSheet APIs', () {
      // Nearly every app call site passes a type argument
      // (`VineBottomSheet.show<bool>(...)`); the rule must match on the
      // method name regardless.
      final omissions = scan('''
void build() {
  VineBottomSheet(onComplete: save, body: body);
  VineBottomSheet.show<bool>(context: context, onComplete: save, body: body);
  ui.VineBottomSheet.show(context: context, onComplete: save, body: body);
}
''');

      expect(omissions, hasLength(6));
      expect(omissions.map((omission) => omission.api).toSet(), {
        'VineBottomSheet',
        'VineBottomSheet.show',
      });
    });

    test(
      'does not count a bottom sheet whose completion control is absent',
      () {
        final omissions = scan('''
void build() {
  VineBottomSheet(body: body);
  VineBottomSheet.show(context: context, onComplete: null, body: body);
}
''');

        expect(omissions, isEmpty);
      },
    );

    test('does not count completion controls in a headerless sheet', () {
      final omissions = scan('''
void build() {
  VineBottomSheet(showHeader: false, onComplete: save, body: body);
  VineBottomSheet.show(
    context: context,
    showHeader: false,
    onComplete: save,
    body: body,
  );
}
''');

      expect(omissions, isEmpty);
    });

    test('ignores a close or done control replaced by a header action', () {
      // VineBottomSheetHeader renders `leadingAction ?? leading` and
      // `trailingAction ?? trailing`: an inline header action takes the slot,
      // a conditional one may still be null at runtime.
      final omissions = scan('''
void build() {
  VineBottomSheet(
    onComplete: save,
    headerLeadingAction: DivineIconButton(icon: icon),
    body: body,
  );
  VineBottomSheet.show<void>(
    context: context,
    onComplete: save,
    headerTrailingAction: const DivineIconButton(icon: icon),
    body: body,
  );
  VineBottomSheet.show<void>(
    context: context,
    onComplete: save,
    headerLeadingAction: canDelete ? DivineIconButton(icon: icon) : null,
    body: body,
  );
}
''');

      expect(omissions.map((omission) => omission.argument), [
        'completeSemanticLabel',
        'closeSemanticLabel',
        'closeSemanticLabel',
        'completeSemanticLabel',
      ]);
      expect(omissions.map((omission) => omission.line), [2, 7, 13, 13]);
    });

    test('counts custom-leading app bars only', () {
      final omissions = scan('''
void build() {
  DiVineAppBar(title: 'Back', showBackButton: true);
  DiVineAppBar(title: 'Custom', leadingIcon: icon);
  DiVineAppBarLeading(
    showBackButton: false,
    onBackPressed: null,
    showMenuButton: false,
    onMenuPressed: null,
    leadingIcon: icon,
    onLeadingPressed: callback,
    style: style,
  );
}
''');

      expect(omissions, hasLength(2));
      expect(omissions.map((omission) => omission.api), [
        'DiVineAppBar',
        'DiVineAppBarLeading',
      ]);
    });

    test('ignores a custom leading icon shadowed by back or menu', () {
      final omissions = scan('''
void build() {
  DiVineAppBarLeading(
    showBackButton: true,
    onBackPressed: back,
    showMenuButton: false,
    onMenuPressed: null,
    leadingIcon: icon,
    onLeadingPressed: callback,
    style: style,
  );
  DiVineAppBarLeading(
    showBackButton: false,
    onBackPressed: null,
    showMenuButton: true,
    onMenuPressed: menu,
    leadingIcon: icon,
    onLeadingPressed: callback,
    style: style,
  );
}
''');

      expect(omissions, isEmpty);
    });

    test('counts dismissible snackbar constructor and static helper', () {
      final omissions = scan('''
void build() {
  DivineSnackbarContainer(label: 'Saved');
  DivineSnackbarContainer(label: 'Saved', onDismissPressed: dismiss);
  DivineSnackbarContainer.snackBar('Saved', onDismissPressed: dismiss);
}
''');

      expect(omissions, hasLength(2));
      expect(omissions.map((omission) => omission.api), [
        'DivineSnackbarContainer',
        'DivineSnackbarContainer.snackBar',
      ]);
    });

    test('ignores unrelated methods with the same terminal name', () {
      final omissions = scan('''
void build() {
  controller.show(onComplete: save);
  OtherAuthTextField(obscureText: true);
  // DivineAuthTextField(obscureText: true);
  final example = 'VineBottomSheet(onComplete: save)';
}
''');

      expect(omissions, isEmpty);
    });

    test('records stable detail metadata', () {
      final omissions = scan('''
void build() {
  DivineSnackbarContainer(label: 'Saved', onDismissPressed: dismiss);
}
''');

      expect(omissions.single.path, 'subject.dart');
      expect(omissions.single.line, 2);
      expect(omissions.single.argument, 'dismissSemanticLabel');
    });
  });
}
