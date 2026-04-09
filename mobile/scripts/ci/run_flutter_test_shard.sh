#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <shard-index> <shard-count>" >&2
  exit 64
fi

shard_index="$1"
shard_count="$2"

if ! [[ "$shard_index" =~ ^[0-9]+$ ]] || ! [[ "$shard_count" =~ ^[0-9]+$ ]]; then
  echo "shard index and shard count must be integers" >&2
  exit 64
fi

if (( shard_count < 1 )); then
  echo "shard count must be >= 1" >&2
  exit 64
fi

if (( shard_index < 0 || shard_index >= shard_count )); then
  echo "shard index must be between 0 and shard_count - 1" >&2
  exit 64
fi

test_files=()
while IFS= read -r test_file; do
  test_files+=("$test_file")
done < <(find test -type f -name '*_test.dart' | LC_ALL=C sort)

selected_files=()
for i in "${!test_files[@]}"; do
  if (( i % shard_count == shard_index )); then
    selected_files+=("${test_files[$i]}")
  fi
done

echo "Shard ${shard_index}/${shard_count}"
echo "Selected ${#selected_files[@]} test files"

if (( ${#selected_files[@]} == 0 )); then
  echo "No test files selected for this shard"
  exit 0
fi

printf '%s\n' "${selected_files[@]}"

flutter test --exclude-tags integration "${selected_files[@]}"
