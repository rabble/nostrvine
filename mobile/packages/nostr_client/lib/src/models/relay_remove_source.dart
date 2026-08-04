/// Identifies why a relay is being removed from the configured relay list.
enum RelayRemoveSource {
  /// The user explicitly removed the relay from settings.
  user,

  /// The app removed the relay while reconciling or replacing clients.
  automatic,
}
