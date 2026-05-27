#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=android_sdk.sh
source "${SCRIPT_DIR}/android_sdk.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: ${message}" >&2
    echo "  expected: ${expected}" >&2
    echo "  actual:   ${actual}" >&2
    exit 1
  fi
}

assert_contains() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! grep -qF "$needle" "$file"; then
    echo "FAIL: ${message}" >&2
    echo "  missing: ${needle}" >&2
    echo "  file:    ${file}" >&2
    exit 1
  fi
}

assert_not_contains() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if grep -qF "$needle" "$file"; then
    echo "FAIL: ${message}" >&2
    echo "  unexpected: ${needle}" >&2
    echo "  file:       ${file}" >&2
    exit 1
  fi
}

extract_mise_task() {
  local task_name="$1"
  local file="$2"

  awk -v task="[tasks.${task_name}]" '
    $0 == task { in_task = 1 }
    in_task && $0 ~ /^\[tasks\./ && $0 != task { exit }
    in_task { print }
  ' "$file"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
local_reset_task="${tmp_dir}/local_reset.mise-task"
extract_mise_task local_reset "${REPO_ROOT}/mobile/mise.toml" > "$local_reset_task"

mkdir -p "${tmp_dir}/home"
set +e
env -u ANDROID_HOME -u ANDROID_SDK_ROOT HOME="${tmp_dir}/home" PATH="/usr/bin:/bin" \
  bash "${SCRIPT_DIR}/emulator.sh" --bogus >/dev/null 2>&1
bogus_exit=$?
set -e
assert_eq "2" "$bogus_exit" \
  "emulator.sh should reject unknown arguments before checking emulator availability"

assert_eq "/tmp/.X11-unix/X1" "$(x11_socket_path ':1.0')" \
  "DISPLAY screen suffix should map to the base X socket"
assert_eq "/tmp/.X11-unix/X10" "$(x11_socket_path ':10')" \
  "SSH-forwarded DISPLAY values should map to their X socket"

mkdir -p "${tmp_dir}/bin"
cat > "${tmp_dir}/bin/emulator" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "-list-avds" ]]; then
  printf '%s\n' Pixel_API_35 Medium_Phone_API_36
fi
STUB
chmod +x "${tmp_dir}/bin/emulator"

PATH="${tmp_dir}/bin:${PATH}"
assert_eq "Pixel_API_35" "$(first_available_avd_name)" \
  "default AVD should come from emulator -list-avds"

assert_contains 'bash ../local_stack/up.sh' "${REPO_ROOT}/mobile/mise.toml" \
  "mise local_up tasks should delegate to the shared stack launcher"
assert_contains 'docker compose -f ../local_stack/docker-compose.yml down -v' "$local_reset_task" \
  "mise local_reset should wipe local stack volumes before restart"
assert_contains 'bash ../local_stack/up.sh' "$local_reset_task" \
  "mise local_reset should delegate restart to the shared stack launcher"
assert_not_contains 'rm -rf "$SCRIPT_DIR/master.key"' "${SCRIPT_DIR}/setup.sh" \
  "setup should not recursively delete a non-empty master.key directory"
assert_not_contains 'docker compose -f "$COMPOSE_FILE" up -d "${PULL_ARGS[@]}"' "${SCRIPT_DIR}/up.sh" \
  "up.sh should not start one-shot seed containers during default stack startup"
assert_contains 'docker compose -f "$COMPOSE_FILE" run --rm e2e-seed' "${SCRIPT_DIR}/up.sh" \
  "up.sh should run e2e-seed as an explicit lifecycle step"
assert_contains 'profiles: ["seed"]' "${SCRIPT_DIR}/docker-compose.yml" \
  "e2e-seed should be excluded from default compose up"

cat > "${tmp_dir}/bin/uname" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' Darwin
STUB
chmod +x "${tmp_dir}/bin/uname"

set +e
env -u DISPLAY AVD_NAME=Pixel_API_35 X11_SOCKET_DIR="${tmp_dir}/missing-x11" \
  PATH="${tmp_dir}/bin:${PATH}" HOME="${tmp_dir}/home" \
  bash "${SCRIPT_DIR}/emulator.sh" >/dev/null 2>"${tmp_dir}/darwin-emulator.err"
darwin_emulator_exit=$?
set -e
assert_eq "0" "$darwin_emulator_exit" \
  "Darwin emulator launch should not require Linux X11 socket discovery"

echo "android script checks passed"
