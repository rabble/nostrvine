# ABOUTME: Prints one line per VineTheme.*Font(...) call that passes no color:,
# ABOUTME: i.e. a text style whose color silently comes from the ambient style.
#
# Reads a CODE-ONLY stream (pipe the file through lib/dart_code_only.awk first)
# so a Font( inside a comment or a string literal never counts. Arguments are
# delimited by balanced-paren scanning rather than a regex, so a nested call
# that itself takes a color: (VineTheme.bodyMediumFont(color: pick(a, b))) is
# read as one argument list and correctly counted as explicit.
#
# Chained calls are followed past the Font(...) parens, so a color handed to a
# cascade (VineTheme.bodyMediumFont().copyWith(color: x)) counts as explicit
# too — the style does end up with a color, and flagging it would tell the
# author to pass one they already passed.
#
# Consumed by check_implicit_font_color_ceiling.sh.

{ buf = buf $0 "\n" }

# Consumes one balanced argument list from the front of _rest: sets _args to
# its contents and advances _rest past the closing paren.
function consume_balanced(   depth, i, len, ch) {
  depth = 1
  i = 1
  len = length(_rest)
  while (i <= len) {
    ch = substr(_rest, i, 1)
    if (ch == "(") {
      depth++
    } else if (ch == ")") {
      depth--
      if (depth == 0) break
    }
    i++
  }

  _args = substr(_rest, 1, i - 1)
  _rest = substr(_rest, i + 1)
}

END {
  _rest = buf
  while (match(_rest, /VineTheme\.[A-Za-z0-9_]+Font\(/)) {
    head = substr(_rest, RSTART, RLENGTH)
    _rest = substr(_rest, RSTART + RLENGTH)

    consume_balanced()
    args = _args

    while (match(_rest, /^[[:space:]]*\.[A-Za-z0-9_]+\(/)) {
      _rest = substr(_rest, RLENGTH + 1)
      consume_balanced()
      args = args "," _args
    }

    if (args !~ /(^|[^A-Za-z0-9_])color[[:space:]]*:/) print head
  }
}
