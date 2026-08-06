// ABOUTME: Shared model for keycast ATProto provisioning lifecycle states
// ABOUTME: Keeps API, repository, bloc, and UI aligned on status values

/// Client-facing representation of keycast's ATProto provisioning states.
enum AtprotoProvisioningState {
  notLinked,
  pending,
  ready,
  failed,
  disabled,
  unknown;

  factory AtprotoProvisioningState.fromWireName(String? wireName) {
    return switch (wireName) {
      null => AtprotoProvisioningState.notLinked,
      'pending' => AtprotoProvisioningState.pending,
      'ready' => AtprotoProvisioningState.ready,
      'failed' => AtprotoProvisioningState.failed,
      'disabled' => AtprotoProvisioningState.disabled,
      _ => AtprotoProvisioningState.unknown,
    };
  }
}
