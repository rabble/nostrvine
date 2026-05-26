// ABOUTME: Screen-scoped Cubit for the account content-labels settings tile.
// ABOUTME: Reads and persists the account-level self-labels via AccountLabelService.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/account_content_labels/account_content_labels_state.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/account_label_service.dart';

/// Cubit backing `AccountContentLabelsTile`.
///
/// [AccountLabelService.accountLabels] is read synchronously (the service is
/// initialized elsewhere), so [load] emits the current snapshot; [setLabels]
/// persists then re-emits.
class AccountContentLabelsCubit extends Cubit<AccountContentLabelsState> {
  AccountContentLabelsCubit({required AccountLabelService service})
    : _service = service,
      super(const AccountContentLabelsState());

  final AccountLabelService _service;

  void load() => emit(state.copyWith(labels: _service.accountLabels));

  Future<void> setLabels(Set<ContentLabel> labels) async {
    await _service.setAccountLabels(labels);
    emit(state.copyWith(labels: labels));
  }
}
