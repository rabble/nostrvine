#!/bin/bash
# Hook: PostToolUse (Edit|Write)
# Auto-run build_runner when editing files with code generation annotations
#
# Triggers on files containing: @freezed, @riverpod, @JsonSerializable,
#   @GenerateMocks, @HiveType, @DriftDatabase, @DriftAccessor
# Input: JSON with tool_input.file_path
# Output: None (exit 0 on success)

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only process Dart files
if [[ -z "$FILE_PATH" || ! "$FILE_PATH" =~ \.dart$ ]]; then
  exit 0
fi

# Skip already generated files
if [[ "$FILE_PATH" =~ \.g\.dart$ || "$FILE_PATH" =~ \.freezed\.dart$ ]]; then
  exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Check if file contains code generation annotations
if ! grep -qE '@(freezed|riverpod|Riverpod|JsonSerializable|GenerateMocks|HiveType|DriftDatabase|DriftAccessor)' "$FILE_PATH"; then
  exit 0
fi

# Find the package root (directory containing pubspec.yaml)
PACKAGE_DIR="$FILE_PATH"
while [[ "$PACKAGE_DIR" != "/" ]]; do
  PACKAGE_DIR=$(dirname "$PACKAGE_DIR")
  if [[ -f "$PACKAGE_DIR/pubspec.yaml" ]]; then
    break
  fi
done

if [[ ! -f "$PACKAGE_DIR/pubspec.yaml" ]]; then
  exit 0
fi

# Run build_runner in the package directory
cd "$PACKAGE_DIR"
dart run build_runner build --delete-conflicting-outputs 2>&1 || true

exit 0
