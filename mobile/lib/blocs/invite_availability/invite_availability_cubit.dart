import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/repositories/invite_availability_repository.dart';

/// App-wide reactive signup-invite availability.
class InviteAvailabilityCubit extends Cubit<InviteAvailabilityState> {
  InviteAvailabilityCubit({required InviteAvailabilityRepository repository})
    : _repository = repository,
      super(repository.current);

  final InviteAvailabilityRepository _repository;

  /// Loads server client config once for this app session.
  Future<void> load() async {
    final next = await _repository.loadOnce();
    if (!isClosed) emit(next);
  }

  /// Changes the local developer override without touching the server.
  void setOverride(InviteAvailabilityOverride override) {
    _repository.setOverride(override);
    emit(_repository.current);
  }
}
