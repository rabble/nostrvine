// ABOUTME: State for CrosspostSettingsCubit
// ABOUTME: Tracks crosspost toggle, handle, provisioning status, and loading

part of 'crosspost_settings_cubit.dart';

enum CrosspostSettingsStatus { initial, loading, loaded, toggling, failure }

class CrosspostSettingsState extends Equatable {
  const CrosspostSettingsState({
    this.status = CrosspostSettingsStatus.initial,
    this.enabled = false,
    this.handle,
    this.provisioningState,
  });

  final CrosspostSettingsStatus status;
  final bool enabled;
  final String? handle;
  final String? provisioningState;

  /// Whether the account has been fully provisioned on Bluesky.
  bool get isProvisioned => provisioningState == 'ready';

  CrosspostSettingsState copyWith({
    CrosspostSettingsStatus? status,
    bool? enabled,
    String? handle,
    String? provisioningState,
  }) {
    return CrosspostSettingsState(
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      handle: handle ?? this.handle,
      provisioningState: provisioningState ?? this.provisioningState,
    );
  }

  @override
  List<Object?> get props => [status, enabled, handle, provisioningState];
}
