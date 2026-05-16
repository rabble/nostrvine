import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

List<InlineSpan> localizedActorSentenceSpans({
  required String fullText,
  required String actorName,
}) {
  final actorStart = fullText.indexOf(actorName);
  if (actorName.isEmpty || actorStart < 0) {
    return [TextSpan(text: fullText, style: VineTheme.bodyMediumFont())];
  }

  final actorEnd = actorStart + actorName.length;
  return [
    if (actorStart > 0)
      TextSpan(
        text: fullText.substring(0, actorStart),
        style: VineTheme.bodyMediumFont(),
      ),
    TextSpan(text: actorName, style: VineTheme.labelLargeFont()),
    if (actorEnd < fullText.length)
      TextSpan(
        text: fullText.substring(actorEnd),
        style: VineTheme.bodyMediumFont(),
      ),
  ];
}
