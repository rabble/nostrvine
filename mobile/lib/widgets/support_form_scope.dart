// ABOUTME: Owns a support sheet's form controllers for the sheet's lifetime
// ABOUTME: Shares them between the scrollable body and the pinned footer

import 'package:flutter/widgets.dart';
import 'package:openvine/widgets/support_form_fields.dart';

/// Creates [T] when the sheet mounts, exposes it to every sheet slot, and
/// disposes it once the sheet subtree is gone.
///
/// `VineBottomSheet` renders its scrollable body and its pinned footer as
/// siblings, so form controllers can live in neither. Creating them at the
/// call site and disposing them after `VineBottomSheet.show` completes does
/// not work either: the exit animation still rebuilds the form, and a
/// `TextField` re-subscribes to its controller on every rebuild — which
/// throws once that controller is disposed.
class SupportFormScope<T extends SupportFormFields> extends StatefulWidget {
  const SupportFormScope({
    required this.create,
    required this.child,
    super.key,
  });

  final T Function() create;
  final Widget child;

  /// The form state held by the nearest [SupportFormScope] of type [T].
  static T of<T extends SupportFormFields>(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_SupportFormScopeData<T>>();
    if (scope == null) {
      throw FlutterError('No SupportFormScope<$T> above this widget.');
    }
    return scope.fields;
  }

  @override
  State<SupportFormScope<T>> createState() => _SupportFormScopeState<T>();
}

class _SupportFormScopeState<T extends SupportFormFields>
    extends State<SupportFormScope<T>> {
  late final T _fields = widget.create();

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SupportFormScopeData<T>(fields: _fields, child: widget.child);
}

class _SupportFormScopeData<T extends SupportFormFields>
    extends InheritedWidget {
  const _SupportFormScopeData({required this.fields, required super.child});

  final T fields;

  @override
  bool updateShouldNotify(_SupportFormScopeData<T> oldWidget) =>
      !identical(fields, oldWidget.fields);
}
