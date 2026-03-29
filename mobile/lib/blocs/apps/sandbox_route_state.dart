part of 'sandbox_route_cubit.dart';

enum SandboxRouteStatus { initial, loading, resolved, missing }

class SandboxRouteState extends Equatable {
  const SandboxRouteState({
    this.status = SandboxRouteStatus.initial,
    this.app,
  });

  final SandboxRouteStatus status;
  final NostrAppDirectoryEntry? app;

  SandboxRouteState copyWith({
    SandboxRouteStatus? status,
    NostrAppDirectoryEntry? app,
  }) {
    return SandboxRouteState(
      status: status ?? this.status,
      app: app ?? this.app,
    );
  }

  @override
  List<Object?> get props => [status, app];
}
