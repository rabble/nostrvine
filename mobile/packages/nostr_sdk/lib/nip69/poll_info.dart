import '../event.dart';

class PollInfo {
  List<List<String>> pollOptions = [];

  int? valueMaximum;

  int? valueMinimum;

  String? consensusThreshold;

  int? closedAt;

  PollInfo.fromEvent(Event event) {
    var length = event.tags.length;
    for (var i = 0; i < length; i++) {
      var tag = event.tags[i];
      var tagLength = tag.length;
      if (tagLength > 1) {
        if (tag[0] == "poll_option" && tagLength > 2) {
          pollOptions.add([tag[1], tag[2]]);
        } else if (tag[0] == "value_maximum") {
          valueMaximum = int.tryParse(tag[1]);
        } else if (tag[0] == "value_minimum") {
          valueMinimum = int.tryParse(tag[1]);
        } else if (tag[0] == "consensus_threshold") {
          consensusThreshold = tag[1];
        } else if (tag[0] == "closed_at") {
          closedAt = int.tryParse(tag[1]);
        }
      }
    }
  }
}
