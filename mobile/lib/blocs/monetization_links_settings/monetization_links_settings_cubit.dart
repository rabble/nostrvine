// ABOUTME: Screen-scoped Cubit for profile monetization links settings.
// ABOUTME: Owns validation, hidden-link preservation, save lifecycle, and analytics.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/monetization_links_settings/monetization_links_settings_state.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

typedef MonetizationAnalyticsSink = void Function(MonetizationLink link);

typedef MonetizationProfileSaved = FutureOr<void> Function(UserProfile profile);

class MonetizationLinksSettingsCubit
    extends Cubit<MonetizationLinksSettingsState> {
  MonetizationLinksSettingsCubit({
    required ProfileRepository? repository,
    required UserProfile? profile,
    required List<MonetizationLinkProvider> visibleProviders,
    required MonetizationAnalyticsSink trackConfiguredLink,
    required MonetizationProfileSaved onProfileSaved,
  }) : _repository = repository,
       _trackConfiguredLink = trackConfiguredLink,
       _onProfileSaved = onProfileSaved,
       super(
         _stateFromProfile(
           currentProfile: profile,
           visibleProviders: visibleProviders,
         ),
       );

  final ProfileRepository? _repository;
  final MonetizationAnalyticsSink _trackConfiguredLink;
  final MonetizationProfileSaved _onProfileSaved;

  void setEnabled(MonetizationLinkProvider provider, bool value) {
    emit(
      state.copyWith(
        enabled: {...state.enabled, provider: value},
        errors: _withoutProvider(state.errors, provider),
        status: MonetizationLinksSettingsSaveStatus.idle,
        clearFailure: true,
        clearSavedProfile: true,
      ),
    );
  }

  void setValue(MonetizationLinkProvider provider, String value) {
    emit(
      state.copyWith(
        values: {...state.values, provider: value},
        errors: _withoutProvider(state.errors, provider),
        status: MonetizationLinksSettingsSaveStatus.idle,
        clearFailure: true,
        clearSavedProfile: true,
      ),
    );
  }

  Future<void> save() async {
    final currentProfile = state.currentProfile;
    final repository = _repository;
    if (currentProfile == null || repository == null || state.isSaving) return;

    final visibleProviderSet = state.visibleProviders.toSet();
    final visibleLinks = <MonetizationLink>[];
    final errors =
        <MonetizationLinkProvider, MonetizationLinkInputInvalidReason>{};

    for (final provider in state.visibleProviders) {
      final input = state.valueFor(provider);
      if (!state.isEnabled(provider)) continue;
      final result = normalizeMonetizationLinkInput(
        provider: provider,
        input: input,
        enabled: true,
      );
      switch (result) {
        case MonetizationLinkInputValid(:final link):
          visibleLinks.add(link);
        case MonetizationLinkInputInvalid(:final reason):
          errors[provider] = reason;
      }
    }

    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          errors: errors,
          status: MonetizationLinksSettingsSaveStatus.idle,
          clearFailure: true,
          clearSavedProfile: true,
        ),
      );
      return;
    }

    final links = [
      ...currentProfile.monetizationLinks.where(
        (link) => !visibleProviderSet.contains(link.provider),
      ),
      ...visibleLinks,
    ];

    emit(
      state.copyWith(
        status: MonetizationLinksSettingsSaveStatus.saving,
        errors: const {},
        clearFailure: true,
        clearSavedProfile: true,
      ),
    );

    try {
      Log.info(
        'Saving monetization links: count=${links.length}',
        name: 'MonetizationLinksSettingsCubit',
        category: LogCategory.system,
      );
      final saved = await repository.saveProfileEvent(
        displayName: currentProfile.displayName ?? currentProfile.name ?? '',
        about: currentProfile.about,
        website: currentProfile.website,
        picture: currentProfile.picture,
        banner: currentProfile.banner,
        currentProfile: currentProfile,
        monetizationLinks: links,
      );
      await _onProfileSaved(saved);
      if (isClosed) return;
      Log.info(
        'Saved monetization links: count=${saved.enabledMonetizationLinks.length}',
        name: 'MonetizationLinksSettingsCubit',
        category: LogCategory.system,
      );
      for (final link in visibleLinks) {
        _trackConfiguredLink(link);
      }
      emit(
        _stateFromProfile(
          currentProfile: saved,
          visibleProviders: state.visibleProviders,
        ).copyWith(
          status: MonetizationLinksSettingsSaveStatus.success,
          savedProfile: saved,
          savedVisibleLinks: visibleLinks,
          clearFailure: true,
        ),
      );
    } on NoRelaysConnectedException catch (error, stackTrace) {
      _emitFailure(
        error,
        stackTrace,
        MonetizationLinksSettingsSaveFailure.noRelays,
      );
    } on ProfilePublishFailedException catch (error, stackTrace) {
      _emitFailure(
        error,
        stackTrace,
        MonetizationLinksSettingsSaveFailure.publishFailed,
      );
    }
  }

  void _emitFailure(
    Object error,
    StackTrace stackTrace,
    MonetizationLinksSettingsSaveFailure failure,
  ) {
    addError(error, stackTrace);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: MonetizationLinksSettingsSaveStatus.failure,
        failure: failure,
        clearSavedProfile: true,
      ),
    );
  }

  static MonetizationLinksSettingsState _stateFromProfile({
    required UserProfile? currentProfile,
    required List<MonetizationLinkProvider> visibleProviders,
  }) {
    final byProvider = {
      for (final link
          in currentProfile?.monetizationLinks ?? const <MonetizationLink>[])
        link.provider: link,
    };
    return MonetizationLinksSettingsState(
      currentProfile: currentProfile,
      visibleProviders: visibleProviders,
      values: {
        for (final provider in MonetizationLinkProvider.values)
          provider: byProvider[provider]?.url ?? '',
      },
      enabled: {
        for (final provider in MonetizationLinkProvider.values)
          provider: byProvider[provider]?.enabled ?? false,
      },
    );
  }

  static Map<MonetizationLinkProvider, MonetizationLinkInputInvalidReason>
  _withoutProvider(
    Map<MonetizationLinkProvider, MonetizationLinkInputInvalidReason> errors,
    MonetizationLinkProvider provider,
  ) {
    if (!errors.containsKey(provider)) return errors;
    return {...errors}..remove(provider);
  }
}
