#!/usr/bin/env bash
# Behavioural checks for preflight.sh and up.sh.
#
# Every case runs the real code against a sandboxed PATH holding a stubbed
# `docker` (plus whichever of `ss`/`lsof` the case wants to exist), so the
# outcome depends only on the fixtures — no daemon, no listening sockets, same
# result on macOS and Linux.
#
#   bash local_stack/test_stack_scripts.sh
#
# shellcheck disable=SC2016  # snippets expand inside the sandboxed shell, not here
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="${SCRIPT_DIR}/preflight.sh"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
BASH_BIN="$(command -v bash)"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

BIN="${tmp_dir}/bin"
FIXTURES="${tmp_dir}/fixtures"
mkdir -p "$BIN" "$FIXTURES"

failures=0

fail() {
    echo "FAIL: $1" >&2
    shift
    local line
    for line in "$@"; do
        echo "  ${line}" >&2
    done
    failures=$((failures + 1))
}

assert_status() {
    local expected="$1" actual="$2" message="$3"

    if [[ "$actual" != "$expected" ]]; then
        fail "$message" "expected exit ${expected}, got ${actual}" \
            "stderr:" "$(sed 's/^/    /' "${tmp_dir}/err")"
    fi
}

assert_stderr_contains() {
    local needle="$1" message="$2"

    if ! grep -qF -- "$needle" "${tmp_dir}/err"; then
        fail "$message" "missing from stderr: ${needle}" \
            "stderr:" "$(sed 's/^/    /' "${tmp_dir}/err")"
    fi
}

assert_stderr_lacks() {
    local needle="$1" message="$2"

    if grep -qF -- "$needle" "${tmp_dir}/err"; then
        fail "$message" "unexpected in stderr: ${needle}" \
            "stderr:" "$(sed 's/^/    /' "${tmp_dir}/err")"
    fi
}

# --- Sandbox ----------------------------------------------------------------

# Only what these scripts and the stubs actually shell out to. `ss` and `lsof`
# are left out on purpose: each case links in the ones it wants to exist.
link_core_tools() {
    local tool path
    for tool in bash cat awk sed grep tr uname python3 dirname mktemp tee tail rm; do
        path="$(command -v "$tool" || true)"
        if [[ -z "$path" ]]; then
            echo "ERROR: ${tool} is required to run these checks" >&2
            exit 1
        fi
        ln -sf "$path" "${BIN}/${tool}"
    done
}

cat >"${BIN}/docker" <<'STUB'
#!/usr/bin/env bash
# Serves canned output and exit codes from $STUB_FIXTURES. Unknown invocations
# succeed silently, which is close enough to the real client for the paths
# under test.
set -u

emit() { [[ -f "$1" ]] && cat "$1"; return 0; }

# Exit code for a stubbed subcommand, 0 unless the case asked otherwise.
stub_rc() {
    local rc_file="${STUB_FIXTURES}/rc_$1"
    if [[ -f "$rc_file" ]]; then
        cat "$rc_file"
    else
        echo 0
    fi
}

case "${1:-}" in
  ps)
    # The daemon liveness probe: `docker ps --format '{{.Names}}'`.
    if [[ "${3:-}" == '{{.Names}}' ]]; then
      exit "$(stub_rc daemon)"
    fi
    emit "${STUB_FIXTURES}/docker_ps.txt"
    ;;
  compose)
    shift
    while (($# > 0)); do
      case "$1" in
        config)
          emit "${STUB_FIXTURES}/compose_config.json"
          exit 0
          ;;
        up)
          emit "${STUB_FIXTURES}/up_output.txt"
          exit "$(stub_rc up)"
          ;;
        run)
          emit "${STUB_FIXTURES}/seed_output.txt"
          exit "$(stub_rc run)"
          ;;
        ps)
          # Two different --format strings; ExitCode marks the pipe-delimited one.
          if printf '%s\n' "$@" | grep -q 'ExitCode'; then
            emit "${STUB_FIXTURES}/compose_ps_pipe.txt"
          else
            emit "${STUB_FIXTURES}/compose_ps_table.txt"
          fi
          exit 0
          ;;
        logs)
          shift
          for arg in "$@"; do
            [[ "$arg" == --* ]] && continue
            emit "${STUB_FIXTURES}/logs_${arg}.txt"
          done
          exit 0
          ;;
      esac
      shift
    done
    ;;
esac
exit 0
STUB
chmod +x "${BIN}/docker"

cat >"${BIN}/ss.stub" <<'STUB'
#!/usr/bin/env bash
# `ss -Hltn`: State Recv-Q Send-Q Local Peer
cat "${STUB_FIXTURES}/ss.txt" 2>/dev/null
exit 0
STUB

cat >"${BIN}/lsof.stub" <<'STUB'
#!/usr/bin/env bash
# `lsof -nP -iTCP -sTCP:LISTEN -Fn`: one n<address>:<port> record per socket.
cat "${STUB_FIXTURES}/lsof.txt" 2>/dev/null
exit 0
STUB

link_core_tools

# with_tools <tool>... — exactly these of ss/lsof exist for the next run.
with_tools() {
    rm -f "${BIN}/ss" "${BIN}/lsof"
    local tool
    for tool in "$@"; do
        cp "${BIN}/${tool}.stub" "${BIN}/${tool}"
        chmod +x "${BIN}/${tool}"
    done
}

# drop_python — the next run has no python3 on PATH.
drop_python() { rm -f "${BIN}/python3"; }

reset_fixtures() {
    rm -f "${FIXTURES}"/*
    cat >"${FIXTURES}/compose_config.json" <<'JSON'
{
  "name": "local_stack",
  "services": {
    "funnelcake-redis": {
      "ports": [{"published": "16380", "target": 6379, "protocol": "tcp"}]
    },
    "keycast": {
      "ports": [{"published": "45173", "target": 5173, "protocol": "tcp"}]
    }
  }
}
JSON
}

sandbox_env() {
    env -i PATH="$BIN" HOME="$tmp_dir" STUB_FIXTURES="$FIXTURES" "$@"
}

# run_in_sandbox <snippet> [arg]...
# The snippet runs in a fresh shell with preflight.sh sourced; $1 is the script
# itself, $2 the compose file, $3.. whatever the caller passes. Errexit is the
# caller's business, so the exit status survives.
run_in_sandbox() {
    local snippet="$1"
    shift

    sandbox_env "$BASH_BIN" -c "source \"\$1\"; ${snippet}" \
        _ "$PREFLIGHT" "$COMPOSE_FILE" "$@" \
        >"${tmp_dir}/out" 2>"${tmp_dir}/err"
}

run_preflight() {
    set +e
    run_in_sandbox 'preflight_ports "$2"'
    last_status=$?
    set -e
}

run_transient() {
    set +e
    run_in_sandbox 'stack_failure_is_transient "$2" "$3" "${@:4}"' "$@"
    last_status=$?
    set -e
}

run_up_sh() {
    set +e
    sandbox_env "$BASH_BIN" "${SCRIPT_DIR}/up.sh" \
        >"${tmp_dir}/out" 2>"${tmp_dir}/err"
    last_status=$?
    set -e
}

# --- A stale container holding a stack port is a conflict -------------------
# The bug this replaces: with no `ss` on the box the listener map stayed empty,
# every port was skipped, and pre-flight returned 0 into a doomed `up`.

reset_fixtures
with_tools lsof
echo 'stale-redis||0.0.0.0:16380->6379/tcp, [::]:16380->6379/tcp' >"${FIXTURES}/docker_ps.txt"
echo 'n*:16380' >"${FIXTURES}/lsof.txt"
run_preflight

assert_status 1 "$last_status" "a container on a stack port should fail pre-flight without ss"
assert_stderr_contains 'port 16380' "the conflicting port should be named"
assert_stderr_contains 'wanted by service "funnelcake-redis"' "the service that wanted the port should be named"
assert_stderr_contains 'held by container "stale-redis"' "the holding container should be named"
assert_stderr_contains 'standalone container (no compose project)' "a container with no compose label should be called standalone"
assert_stderr_contains 'docker rm -f stale-redis' "the remedy should be printed"
# bash 3.2 is the only bash on macOS, and `mise run local_up` runs plain `bash`.
assert_stderr_lacks 'invalid option' "no bash-4-only syntax should reach stderr"

# --- Same conflict, no ss and no lsof ---------------------------------------
# Container-held ports come from `docker ps`, so they are still caught; the
# host-process blind spot is stated rather than passed over.

reset_fixtures
with_tools
echo 'stale-redis||0.0.0.0:16380->6379/tcp' >"${FIXTURES}/docker_ps.txt"
run_preflight

assert_status 1 "$last_status" "a container conflict should be caught with neither ss nor lsof"
assert_stderr_contains 'held by container "stale-redis"' "the holding container should still be named"
assert_stderr_contains "neither 'ss' nor 'lsof' is installed" "the blind spot should be stated out loud"

# --- A host process holding a stack port ------------------------------------

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
echo 'n127.0.0.1:45173' >"${FIXTURES}/lsof.txt"
run_preflight

assert_status 1 "$last_status" "a host process on a stack port should fail pre-flight"
assert_stderr_contains 'held by a host process (not a container)' "a non-container holder should be described as one"
assert_stderr_contains '127.0.0.1:45173' "the listening address should be shown"
assert_stderr_contains 'sudo lsof -nP -iTCP:45173 -sTCP:LISTEN' "the remedy should use lsof where ss is absent"

# --- ...and the remedy follows the tool the machine has ---------------------

reset_fixtures
with_tools ss
: >"${FIXTURES}/docker_ps.txt"
echo 'LISTEN 0 4096 127.0.0.1:45173 0.0.0.0:*' >"${FIXTURES}/ss.txt"
run_preflight

assert_status 1 "$last_status" "ss output should drive the same conflict report"
assert_stderr_contains 'ss -ltnp "sport = :45173"' "the remedy should use ss where it exists"

# --- Our own stack is not a conflict ----------------------------------------

reset_fixtures
with_tools lsof
echo 'local_stack-funnelcake-redis-1|local_stack|0.0.0.0:16380->6379/tcp' >"${FIXTURES}/docker_ps.txt"
echo 'n*:16380' >"${FIXTURES}/lsof.txt"
run_preflight

assert_status 0 "$last_status" "a port already published by this project should not be a conflict"

# --- Nothing holding anything -----------------------------------------------

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
: >"${FIXTURES}/lsof.txt"
run_preflight

assert_status 0 "$last_status" "a clean machine should pass pre-flight"

# --- An unreadable port list fails closed -----------------------------------
# Empty output from a broken extractor reads exactly like "publishes no ports".

reset_fixtures
with_tools lsof
echo 'stale-redis||0.0.0.0:16380->6379/tcp' >"${FIXTURES}/docker_ps.txt"
drop_python
run_preflight
link_core_tools

assert_status 1 "$last_status" "pre-flight should fail closed when it cannot read the port list"
assert_stderr_contains 'needs python3' "the missing dependency should be named"

# --- An unreachable daemon fails closed -------------------------------------

reset_fixtures
with_tools lsof
echo 1 >"${FIXTURES}/rc_daemon"
run_preflight

assert_status 1 "$last_status" "pre-flight should fail closed when the daemon is unreachable"
assert_stderr_contains 'cannot talk to the Docker daemon' "the daemon should be named as the problem"

# --- Transience is judged on the failed service's own log -------------------
# A retry-worthy signature in a service that came up fine is not evidence, and
# acting on it costs two more `up --wait` cycles before the real report prints.

reset_fixtures
with_tools lsof
cat >"${FIXTURES}/compose_ps_pipe.txt" <<'PS'
keycast|running|0
funnelcake-migrate|exited|1
minio-init|exited|0
PS
echo 'dial tcp: i/o timeout' >"${FIXTURES}/logs_keycast.txt"
echo 'migration failed: permission denied' >"${FIXTURES}/logs_funnelcake-migrate.txt"
echo 'dependency failed to start' >"${tmp_dir}/up.log"

run_transient "${tmp_dir}/up.log" keycast funnelcake-migrate minio-init
assert_status 1 "$last_status" "a healthy service's log should not make a hard failure look transient"

echo 'lookup funnelcake-clickhouse on 127.0.0.11:53: no such host' >"${FIXTURES}/logs_funnelcake-migrate.txt"

run_transient "${tmp_dir}/up.log" keycast funnelcake-migrate minio-init
assert_status 0 "$last_status" "a name-resolution failure in the down service should be transient"

# --- Nothing down means nothing to retry ------------------------------------

reset_fixtures
with_tools lsof
cat >"${FIXTURES}/compose_ps_pipe.txt" <<'PS'
keycast|running|0
minio-init|exited|0
PS
echo 'dial tcp: i/o timeout' >"${FIXTURES}/logs_keycast.txt"

run_transient "${tmp_dir}/up.log" keycast minio-init
assert_status 1 "$last_status" "with every service up there is no failed log to call transient"

# --- A failed seed reports the seed, not the healthy services ---------------
# The services came up; saying "Local stack failed to come up" over a list of
# 15 healthy ones buries the one log that explains the failure.

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
: >"${FIXTURES}/lsof.txt"
echo 'Container local_stack-keycast-1  Healthy' >"${FIXTURES}/up_output.txt"
cat >"${FIXTURES}/seed_output.txt" <<'SEED'
seeding 100 videos
error: blossom upload failed: connection refused
SEED
echo 3 >"${FIXTURES}/rc_run"
cat >"${FIXTURES}/compose_ps_table.txt" <<'PS'
keycast	running	Up 2 minutes (healthy)
PS
run_up_sh

assert_status 3 "$last_status" "up.sh should exit with the seed's own status"
assert_stderr_contains '=== e2e-seed failed ===' "the seed should be named as what failed"
assert_stderr_contains 'blossom upload failed: connection refused' "the seed's own error should be shown"
assert_stderr_lacks '=== Local stack failed to come up ===' "the stack came up, so it should not claim otherwise"
assert_stderr_contains 'Service status:' "the service table still helps explain a seed failure"
assert_stderr_contains 'profile.sh' "the bypass command should still be offered"

# ----------------------------------------------------------------------------

if ((failures > 0)); then
    echo "${failures} local stack check(s) failed" >&2
    exit 1
fi

echo "local stack script checks passed"
