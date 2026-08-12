// ABOUTME: Screen-scoped Cubit for choosing Nostr signature verification policy.
// ABOUTME: Persists policy changes without exposing preference services to UI.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/nostr_signature_verification_policy.dart';
import 'package:openvine/services/nostr_signature_verification_preference_service.dart';

class SignatureVerificationPolicyCubit
    extends Cubit<NostrSignatureVerificationPolicy> {
  SignatureVerificationPolicyCubit({
    required NostrSignatureVerificationPreferenceService preferenceService,
    required void Function() onPolicyChanged,
  }) : _preferenceService = preferenceService,
       _onPolicyChanged = onPolicyChanged,
       super(preferenceService.currentPolicy);

  final NostrSignatureVerificationPreferenceService _preferenceService;
  final void Function() _onPolicyChanged;

  Future<void> setPolicy(NostrSignatureVerificationPolicy policy) async {
    if (policy == state) return;
    final previous = state;
    emit(policy);
    try {
      await _preferenceService.setPolicy(policy);
      _onPolicyChanged();
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(previous);
    }
  }
}
