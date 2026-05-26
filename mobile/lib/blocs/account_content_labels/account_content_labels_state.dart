// ABOUTME: State for AccountContentLabelsCubit — the user's account-level
// ABOUTME: content self-labels.

import 'package:equatable/equatable.dart';
import 'package:openvine/models/content_label.dart';

/// State for [AccountContentLabelsCubit]: the set of account-level self-labels.
class AccountContentLabelsState extends Equatable {
  const AccountContentLabelsState({this.labels = const {}});

  final Set<ContentLabel> labels;

  AccountContentLabelsState copyWith({Set<ContentLabel>? labels}) =>
      AccountContentLabelsState(labels: labels ?? this.labels);

  @override
  List<Object?> get props => [labels];
}
