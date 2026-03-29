part of 'app_detail_cubit.dart';

enum AppDetailStatus { initial, loading, loaded, notFound }

class AppDetailState extends Equatable {
  const AppDetailState({
    this.status = AppDetailStatus.initial,
    this.app,
  });

  final AppDetailStatus status;
  final NostrAppDirectoryEntry? app;

  AppDetailState copyWith({
    AppDetailStatus? status,
    NostrAppDirectoryEntry? app,
  }) {
    return AppDetailState(
      status: status ?? this.status,
      app: app ?? this.app,
    );
  }

  @override
  List<Object?> get props => [status, app];
}
