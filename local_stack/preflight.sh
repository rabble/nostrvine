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

# --- Host listeners ---------------------------------------------------------

# stdout: one "<address>:<port>" per listening TCP socket.
# `ss` is iproute2, so it does not exist on macOS; `lsof` is there instead.
# Returns 1 when neither is installed, so the caller can say so rather than
# read "no listeners found" as "every port is free".
_stack_listen_addrs() {
    if command -v ss >/dev/null 2>&1; then
        ss -Hltn 2>/dev/null | awk '{ print $4 }'
    elif command -v lsof >/dev/null 2>&1; then
        # -Fn emits one "n<address>:<port>" record per socket, which spares us
        # the header line and the space-separated NAME column. Without sudo it
        # only sees our own processes — enough for Docker Desktop's proxy.
        lsof -nP -iTCP -sTCP:LISTEN -Fn 2>/dev/null | sed -n 's/^n//p'
    else
        return 1
    fi
    return 0
}

# stdout: the command that names what holds <port>, for whichever of ss/lsof
# this machine actually has.
_stack_port_finder_cmd() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        printf 'ss -ltnp "sport = :%s"' "$port"
    else
        printf 'sudo lsof -nP -iTCP:%s -sTCP:LISTEN' "$port"
    fi
}

# --- Pre-flight -------------------------------------------------------------

# preflight_ports <compose_file>
# Returns 0 if every published host port is free or held by this project's own
# containers; 1 (with an actionable report on stderr) otherwise.
preflight_ports() {
    local compose_file="$1"
    local config_json project ports

    if ! docker ps --format '{{.Names}}' >/dev/null 2>&1; then
        local daemon_hint="systemctl status docker"
        if [[ "$(uname -s)" == "Darwin" ]]; then
            daemon_hint="open -a Docker"
        fi
        echo "ERROR: cannot talk to the Docker daemon. Is it running? (${daemon_hint})" >&2
        return 1
    fi

    if ! config_json="$(docker compose -f "$compose_file" config --format json 2>&1)"; then
        echo "ERROR: could not parse ${compose_file}:" >&2
        echo "$config_json" >&2
        return 1
    fi

    # Fail closed. An unreadable port list is indistinguishable from "the stack
    # publishes no ports", and passing on it hands the operator back the
    # anonymous daemon error this whole check exists to replace.
    if ! command -v python3 >/dev/null 2>&1; then
        echo "ERROR: the port pre-flight needs python3 on PATH, and it is missing." >&2
        return 1
    fi

    if ! project="$(printf '%s' "$config_json" | _stack_project_name)" ||
        ! ports="$(printf '%s' "$config_json" | _stack_published_ports)"; then
        echo "ERROR: could not read the published ports out of ${compose_file}." >&2
        return 1
    fi

    if [[ -z "$project" ]]; then
        echo "ERROR: ${compose_file} resolved to an empty compose project name," >&2
        echo "       so this stack's own containers cannot be told apart from others." >&2
        return 1
    fi

    if [[ -z "$ports" ]]; then
        return 0
    fi

    # port -> space-separated local addresses currently listening on it
    local listen_addrs=()
    local listeners_known=1
    local listener_lines local_addr port
    if listener_lines="$(_stack_listen_addrs)"; then
        while read -r local_addr; do
            port="${local_addr##*:}"
            [[ "$port" =~ ^[0-9]+$ ]] || continue
            listen_addrs["$port"]+="${local_addr} "
        done <<<"$listener_lines"
    else
        listeners_known=0
    fi

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

    if ((listeners_known == 0)); then
        {
            echo ""
            echo "WARNING: neither 'ss' nor 'lsof' is installed, so a port held by a"
            echo "         plain host process cannot be detected. Ports held by"
            echo "         containers are still checked below."
        } >&2
    fi

    local service conflicts=0 holder holder_project addrs
    while read -r service port; do
        holder="${port_container[$port]:-}"
        holder_project="${port_project[$port]:-}"
        addrs="${listen_addrs[$port]:-}"

        # A container that published the port clashes even when the listener
        # enumeration cannot see the socket — no ss/lsof, or a listener owned
        # by another user.
        [[ -n "$addrs" || -n "$holder" ]] || continue

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
                    "${addrs% }"
                printf '            find it: %s\n' "$(_stack_port_finder_cmd "$port")"
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

# _stack_down_services <compose_file> <service>...
# stdout: "<service>|<state>" per service that is not up. One-shot jobs
# (migrations, seeding) that exited 0 did their work and are not failures.
_stack_down_services() {
    local compose_file="$1"
    shift

    local service state exit_code
    # `|` for the same reason as above: an empty middle field survives.
    while IFS='|' read -r service state exit_code; do
        [[ -n "$service" ]] || continue
        [[ "$state" == "running" ]] && continue
        [[ "$state" == "exited" && "$exit_code" == "0" ]] && continue
        echo "${service}|${state}"
    done < <(docker compose -f "$compose_file" ps -a --format '{{.Service}}|{{.State}}|{{.ExitCode}}' "$@" 2>/dev/null)
}

# stack_failure_is_transient <compose_file> <up_log> <service>...
# True when the failure looks like a DNS/startup race rather than a real break.
stack_failure_is_transient() {
    local compose_file="$1" up_log="$2"
    shift 2

    if grep -qE "$_STACK_TRANSIENT_RE" "$up_log" 2>/dev/null; then
        return 0
    fi

    # The daemon error is usually generic ("dependency failed to start"); the
    # real signature is in the failed containers' own logs. Only theirs — an
    # `i/o timeout` in the recent output of a service that came up fine would
    # otherwise buy two more pointless `up --wait` cycles before the real
    # report prints.
    local down_services=() service
    while IFS='|' read -r service _; do
        [[ -n "$service" ]] || continue
        down_services+=("$service")
    done < <(_stack_down_services "$compose_file" "$@")

    ((${#down_services[@]} > 0)) || return 1

    local logs
    logs="$(docker compose -f "$compose_file" logs --tail=50 "${down_services[@]}" 2>/dev/null || true)"
    grep -qE "$_STACK_TRANSIENT_RE" <<<"$logs"
}

# stack_service_status <compose_file> <service>...
# The per-service state table, on stderr.
stack_service_status() {
    local compose_file="$1"
    shift

    {
        echo "Service status:"
        docker compose -f "$compose_file" ps -a --format '{{.Service}}	{{.State}}	{{.Status}}' \
            "$@" 2>/dev/null | sed 's/^/  /' || true
        echo ""
    } >&2
}

# stack_bypass_hint <script_dir> <lead_in>
# How to run tests anyway, on stderr.
stack_bypass_hint() {
    local script_dir="$1" lead_in="$2"

    {
        echo "$lead_in"
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

# stack_failure_report <compose_file> <script_dir> <service>...
# Says which services are healthy vs down, and how to run tests anyway.
stack_failure_report() {
    local compose_file="$1" script_dir="$2"
    shift 2

    {
        echo ""
        echo "=== Local stack failed to come up ==="
        echo ""
    } >&2

    stack_service_status "$compose_file" "$@"

    local service state service_logs
    while IFS='|' read -r service state; do
        [[ -n "$service" ]] || continue
        service_logs="$(docker compose -f "$compose_file" logs --tail=20 --no-log-prefix "$service" 2>&1 || true)"
        {
            echo "--- last 20 log lines: ${service} (${state}) ---"
            if [[ -n "$service_logs" ]]; then
                # shellcheck disable=SC2001  # indenting every line, not a substring swap
                sed 's/^/    /' <<<"$service_logs"
            else
                echo "    (no output — the container never started)"
            fi
            echo ""
        } >&2
    done < <(_stack_down_services "$compose_file" "$@")

    stack_bypass_hint "$script_dir" \
        "A service being down does NOT block tests that never call it."
}
