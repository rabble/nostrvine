#!/usr/bin/env bash
# Pre-flight and post-mortem diagnostics for the local E2E stack.
#
# Sourced by up.sh. Two jobs:
#   1. preflight_ports  — before starting anything, prove every host port the
#      stack publishes is free (or already ours). The raw daemon error
#      ("Bind for 0.0.0.0:16380 failed: port is already allocated") names
#      neither the service that wanted the port nor what is holding it.
#   2. stack_failure_is_transient / stack_failure_report — after a failed
#      `up`, tell the operator which services are down and what to do next.
#
# The port list is read from docker-compose.yml via `docker compose config`,
# so it cannot drift from the stack definition.
#
# `mise run local_up` calls plain `bash`, which on macOS is 3.2. No
# associative arrays: every port map below is an indexed array subscripted by
# the port number, which behaves identically on 3.2 and 4+.

# --- Port list, straight from the compose file ------------------------------

# stdout: "<service> <host_port>" per published TCP port.
_stack_published_ports() {
    python3 -c '
import json, sys

doc = json.load(sys.stdin)
for service, config in sorted((doc.get("services") or {}).items()):
    for port in config.get("ports") or []:
        if port.get("protocol", "tcp") != "tcp":
            continue
        published = str(port.get("published") or "")
        if not published:
            continue
        low, _, high = published.partition("-")
        try:
            span = range(int(low), int(high or low) + 1)
        except ValueError:
            continue
        for host_port in span:
            print(service, host_port)
'
}

_stack_project_name() {
    python3 -c 'import json, sys; print(json.load(sys.stdin).get("name", ""))'
}

# --- Pre-flight -------------------------------------------------------------

# preflight_ports <compose_file>
# Returns 0 if every published host port is free or held by this project's own
# containers; 1 (with an actionable report on stderr) otherwise.
preflight_ports() {
    local compose_file="$1"
    local config_json project ports

    if ! docker ps --format '{{.Names}}' >/dev/null 2>&1; then
        echo "ERROR: cannot talk to the Docker daemon. Is it running? (systemctl status docker)" >&2
        return 1
    fi

    if ! config_json="$(docker compose -f "$compose_file" config --format json 2>&1)"; then
        echo "ERROR: could not parse ${compose_file}:" >&2
        echo "$config_json" >&2
        return 1
    fi

    project="$(printf '%s' "$config_json" | _stack_project_name)"
    ports="$(printf '%s' "$config_json" | _stack_published_ports)"
    if [[ -z "$ports" ]]; then
        return 0
    fi

    # port -> space-separated local addresses currently listening on it
    local listen_addrs=()
    local local_addr port
    while read -r _ _ _ local_addr _; do
        port="${local_addr##*:}"
        [[ "$port" =~ ^[0-9]+$ ]] || continue
        listen_addrs["$port"]+="${local_addr} "
    done < <(ss -Hltn 2>/dev/null || true)

    # port -> container name / owning compose project (empty if standalone)
    local port_container=() port_project=()
    local name proj portspec host_port
    # `|` rather than tab: tab is IFS whitespace, so bash collapses a run of
    # them and an empty middle field disappears. A standalone container has no
    # compose-project label, which is exactly the stale-container case this
    # check exists to catch — with tabs its ports column shifts into `proj`
    # and the container is misreported as an anonymous host process.
    while IFS='|' read -r name proj portspec; do
        [[ -n "$name" ]] || continue
        while read -r host_port; do
            [[ -n "$host_port" ]] || continue
            port_container["$host_port"]="$name"
            port_project["$host_port"]="$proj"
        done < <(grep -oE ':[0-9]+->' <<<"$portspec" | tr -d ':>-')
    done < <(docker ps --format '{{.Names}}|{{.Label "com.docker.compose.project"}}|{{.Ports}}' 2>/dev/null)

    local service conflicts=0 holder holder_project
    while read -r service port; do
        [[ -n "${listen_addrs[$port]:-}" ]] || continue

        holder="${port_container[$port]:-}"
        holder_project="${port_project[$port]:-}"

        # Already published by our own stack — `up` is idempotent, not a clash.
        if [[ -n "$holder" && "$holder_project" == "$project" ]]; then
            continue
        fi

        if ((conflicts == 0)); then
            {
                echo ""
                echo "ERROR: host ports the local stack needs are already in use."
                echo ""
            } >&2
        fi
        conflicts=$((conflicts + 1))

        if [[ -n "$holder" ]]; then
            local owner_desc
            if [[ -n "$holder_project" ]]; then
                owner_desc="compose project \"${holder_project}\""
            else
                owner_desc="standalone container (no compose project)"
            fi
            {
                printf '  port %-6s wanted by service "%s"\n' "$port" "$service"
                printf '            held by container "%s" — %s\n' "$holder" "$owner_desc"
                printf '            remedy: docker rm -f %s\n' "$holder"
            } >&2
        else
            {
                printf '  port %-6s wanted by service "%s"\n' "$port" "$service"
                printf '            held by a host process (not a container), listening on: %s\n' \
                    "${listen_addrs[$port]% }"
                printf '            find it: ss -ltnp "sport = :%s"   (or: sudo lsof -iTCP:%s -sTCP:LISTEN)\n' \
                    "$port" "$port"
            } >&2
        fi
        echo "" >&2
    done <<<"$ports"

    if ((conflicts > 0)); then
        {
            echo "${conflicts} port conflict(s). Nothing was started."
            echo "Stale containers from earlier test runs are the usual cause:"
            printf '    docker ps --format %s\n' "'{{.Names}}\t{{.Status}}\t{{.Ports}}'"
            echo ""
        } >&2
        return 1
    fi

    return 0
}

# --- Post-mortem ------------------------------------------------------------

# Startup races that a plain retry fixes: the container came up before Docker's
# embedded DNS had the dependency's alias, so the name did not resolve.
_STACK_TRANSIENT_RE='no such host|Temporary failure in name resolution|Name or service not known|i/o timeout'

# stack_failure_is_transient <compose_file> <up_log> <service>...
# True when the failure looks like a DNS/startup race rather than a real break.
stack_failure_is_transient() {
    local compose_file="$1" up_log="$2"
    shift 2

    if grep -qE "$_STACK_TRANSIENT_RE" "$up_log" 2>/dev/null; then
        return 0
    fi

    # The daemon error is usually generic ("dependency failed to start"); the
    # real signature is in the failed container's own log.
    local logs
    logs="$(docker compose -f "$compose_file" logs --tail=50 "$@" 2>/dev/null || true)"
    grep -qE "$_STACK_TRANSIENT_RE" <<<"$logs"
}

# stack_failure_report <compose_file> <script_dir> <service>...
# Says which services are healthy vs down, and how to run tests anyway.
stack_failure_report() {
    local compose_file="$1" script_dir="$2"
    shift 2

    {
        echo ""
        echo "=== Local stack failed to come up ==="
        echo ""
        echo "Service status:"
        docker compose -f "$compose_file" ps -a --format '{{.Service}}	{{.State}}	{{.Status}}' \
            "$@" 2>/dev/null | sed 's/^/  /' || true
        echo ""

        local service state exit_code
        # `|` for the same reason as above: an empty middle field survives.
        while IFS='|' read -r service state exit_code; do
            [[ -n "$service" ]] || continue
            [[ "$state" == "running" ]] && continue
            # One-shot services (migrations, seeding) legitimately exit 0.
            [[ "$state" == "exited" && "$exit_code" == "0" ]] && continue
            local service_logs
            service_logs="$(docker compose -f "$compose_file" logs --tail=20 --no-log-prefix "$service" 2>&1 || true)"
            echo "--- last 20 log lines: ${service} (${state}) ---"
            if [[ -n "$service_logs" ]]; then
                # shellcheck disable=SC2001  # indenting every line, not a substring swap
                sed 's/^/    /' <<<"$service_logs"
            else
                echo "    (no output — the container never started)"
            fi
            echo ""
        done < <(docker compose -f "$compose_file" ps -a --format '{{.Service}}|{{.State}}|{{.ExitCode}}' "$@" 2>/dev/null)

        echo "A service being down does NOT block tests that never call it."
        echo "profile.sh skips the local_up gate and runs patrol directly:"
        echo ""
        if [[ -n "${E2E_TEST_PATH:-}" ]]; then
            echo "    bash ${script_dir}/profile.sh ${E2E_TEST_PATH}"
        else
            echo "    bash ${script_dir}/profile.sh <test_path>"
            echo ""
            echo "e.g. bash ${script_dir}/profile.sh integration_test/auth/auth_journey_test.dart"
        fi
        echo ""
    } >&2
}
