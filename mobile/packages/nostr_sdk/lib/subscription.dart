import 'event.dart';
import 'filter.dart';
import 'utils/string_util.dart';

/// Representation of a Nostr event subscription.
class Subscription {
  final String _id;
  List<Map<String, dynamic>> filters;
  Function onEvent;

  /// Callback invoked when EOSE (End of Stored Events) is received from all
  /// relays for this subscription.
  void Function()? onEose;

  /// Subscription ID
  String get id => _id;

  Subscription(this.filters, this.onEvent, {String? id, this.onEose})
    : _id = id ?? StringUtil.rndNameStr(16);

  /// Whether [event] satisfies at least one filter in this subscription.
  bool matchesEvent(Event event) {
    for (final filterJson in filters) {
      if (Filter.fromJson(filterJson).checkEvent(event)) return true;
    }
    return false;
  }

  /// Returns the subscription as a Nostr subscription request in JSON format
  List<dynamic> toJson() {
    List<dynamic> json = ["REQ", _id];

    for (Map<String, dynamic> filter in filters) {
      json.add(filter);
    }

    return json;
  }
}
