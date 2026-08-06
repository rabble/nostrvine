import 'event.dart';
import 'filter.dart';
import 'utils/string_util.dart';

/// Representation of a Nostr event subscription.
class Subscription {
  final String _id;
  final List<Map<String, dynamic>> filters;
  Function onEvent;

  /// Callback invoked when EOSE (End of Stored Events) is received from all
  /// relays for this subscription.
  void Function()? onEose;

  /// [filters] parsed once at construction.
  ///
  /// [matchesEvent] runs on every inbound frame, and `Filter.fromJson` copies
  /// each id/author list it is handed — parsing per event would make the
  /// receive path scale with the size of the author set. Parsing here also
  /// means a malformed filter throws at subscribe time rather than being
  /// swallowed per-event by the frame handler's catch-all.
  final List<Filter> _parsedFilters;

  /// Subscription ID
  String get id => _id;

  Subscription(this.filters, this.onEvent, {String? id, this.onEose})
    : _id = id ?? StringUtil.rndNameStr(16),
      _parsedFilters = [for (final filter in filters) Filter.fromJson(filter)];

  /// Whether [event] satisfies at least one filter in this subscription.
  ///
  /// A subscription carrying no filters matches nothing; the pool's entry
  /// points reject an empty filter list before one can be constructed.
  bool matchesEvent(Event event) =>
      _parsedFilters.any((filter) => filter.checkEvent(event));

  /// Returns the subscription as a Nostr subscription request in JSON format
  List<dynamic> toJson() {
    List<dynamic> json = ["REQ", _id];

    for (Map<String, dynamic> filter in filters) {
      json.add(filter);
    }

    return json;
  }
}
