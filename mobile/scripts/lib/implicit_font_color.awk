# ABOUTME: Prints one line per VineTheme.*Font(...) call that passes no color:,
# ABOUTME: i.e. a text style whose color silently comes from the ambient style.
#
# Reads a CODE-ONLY stream (pipe the file through lib/dart_code_only.awk first)
# so a Font( inside a comment or a string literal never counts. Arguments are
# delimited by balanced-paren scanning rather than a regex, so a nested call
# that itself takes a color: (VineTheme.bodyMediumFont(color: pick(a, b))) is
# read as one argument list and correctly counted as explicit.
#
# Consumed by check_implicit_font_color_ceiling.sh.

{ buf = buf $0 "\n" }

END {
  rest = buf
  while (match(rest, /VineTheme\.[A-Za-z0-9_]+Font\(/)) {
    head = substr(rest, RSTART, RLENGTH)
    rest = substr(rest, RSTART + RLENGTH)

    depth = 1
    i = 1
    len = length(rest)
    while (i <= len) {
      ch = substr(rest, i, 1)
      if (ch == "(") {
        depth++
      } else if (ch == ")") {
        depth--
        if (depth == 0) break
      }
      i++
    }

    args = substr(rest, 1, i - 1)
    if (args !~ /(^|[^A-Za-z0-9_])color[[:space:]]*:/) print head
    rest = substr(rest, i + 1)
  }
}
