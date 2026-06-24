/// Direction of a feed-tuning swipe.
///
/// [more] = "more like this" (swipe right); [less] = "less like this"
/// (swipe left). The [tagValue] is what travels in the event's `direction`
/// tag, so the backend reads a stable string rather than an enum index.
enum FeedTuningDirection {
  /// "More like this" — swipe right.
  more,

  /// "Less like this" — swipe left.
  less;

  /// The value written into the event's `["direction", ...]` tag.
  String get tagValue => switch (this) {
    FeedTuningDirection.more => 'more',
    FeedTuningDirection.less => 'less',
  };
}
