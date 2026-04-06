import 'package:app_update_repository/app_update_repository.dart';

/// Resolves the install source on Android from the installer package name.
InstallSource resolveAndroidInstallSource(String? installerPackageName) {
  return switch (installerPackageName) {
    InstallSource.playStoreInstaller => InstallSource.playStore,
    InstallSource.zapstoreInstaller => InstallSource.zapstore,
    _ => InstallSource.sideload,
  };
}

/// Resolves the install source on iOS from the receipt environment.
InstallSource resolveIosInstallSource({required bool isSandbox}) {
  return isSandbox ? InstallSource.testFlight : InstallSource.appStore;
}
