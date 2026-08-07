#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_DIR="$PROJECT_DIR/.runtime"
LOG_DIR="$RUNTIME_DIR/logs"
PID_DIR="$RUNTIME_DIR/pids"
STF_PID_FILE="$PID_DIR/stf.pid"
API_PID_FILE="$PID_DIR/api.pid"
STF_LOG_FILE="$LOG_DIR/stf.log"
API_LOG_FILE="$LOG_DIR/api.log"
RETHINKDB_DIR="$RUNTIME_DIR/rethinkdb"
RETHINKDB_CONTAINER="mobile-matrix-rethinkdb"
STF_LAUNCH_LABEL="com.mobile-matrix.stf"
API_LAUNCH_LABEL="com.mobile-matrix.api"
STF_PORT=7100
DEFAULT_API_PORT=7121
NODE20_BIN="${MOBILE_MATRIX_NODE20_BIN:-/Users/salton/.nvm/versions/node/v20.19.6/bin}"

mkdir -p "$LOG_DIR" "$PID_DIR" "$RETHINKDB_DIR"
cd "$PROJECT_DIR"

log() {
  printf '[mobile-matrix] %s\n' "$*"
}

fail() {
  printf '[mobile-matrix] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

activate_node20() {
  if [ -x "$NODE20_BIN/node" ]; then
    PATH="$NODE20_BIN:$PATH"
    export PATH
  fi

  require_command node
  require_command npm

  local node_major
  node_major="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$node_major" = "20" ] || fail \
    "Node.js 20 is required. Set MOBILE_MATRIX_NODE20_BIN to its bin directory."
}

stop_launch_service() {
  local launch_label="$1"
  local service_name="$2"

  if launchctl list "$launch_label" >/dev/null 2>&1; then
    log "Stopping previous $service_name service"
    launchctl remove "$launch_label"
    sleep 2
  fi
}

record_launch_pid() {
  local launch_label="$1"
  local pid_file="$2"
  local pid

  pid="$(launchctl list | awk -v label="$launch_label" '$3 == label {print $1}')"
  if [ -n "$pid" ] && [ "$pid" != "-" ]; then
    printf '%s\n' "$pid" >"$pid_file"
  else
    rm -f "$pid_file"
  fi
}

port_listener_pid() {
  /usr/sbin/lsof -nP -tiTCP:"$1" -sTCP:LISTEN 2>/dev/null | sed -n '1p' || true
}

assert_port_available() {
  local port="$1"
  local service_name="$2"
  local pid
  local command_line

  pid="$(port_listener_pid "$port")"
  [ -z "$pid" ] && return 0

  command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  fail "$service_name port $port is already used by PID $pid: $command_line"
}

wait_for_http() {
  local name="$1"
  local url="$2"
  local log_file="$3"
  local attempts=0

  while [ "$attempts" -lt 60 ]; do
    if curl -fsSL --max-time 2 "$url" >/dev/null 2>&1; then
      log "$name is ready: $url"
      return 0
    fi
    sleep 1
    attempts=$((attempts + 1))
  done

  printf '[mobile-matrix] Last %s log lines:\n' "$name" >&2
  tail -n 30 "$log_file" >&2 || true
  fail "$name did not become ready within 60 seconds"
}

start_colima() {
  require_command colima
  require_command docker

  if ! colima status >/dev/null 2>&1; then
    log "Starting Colima"
    colima start --cpu 4 --memory 6
  fi
}

restart_rethinkdb() {
  if docker inspect "$RETHINKDB_CONTAINER" >/dev/null 2>&1; then
    log "Restarting RethinkDB container"
    docker restart "$RETHINKDB_CONTAINER" >/dev/null
  else
    log "Creating RethinkDB container"
    docker run -d \
      --platform linux/amd64 \
      --name "$RETHINKDB_CONTAINER" \
      -p 127.0.0.1:28015:28015 \
      -v "$RETHINKDB_DIR:/data" \
      rethinkdb:2.4.2 \
      rethinkdb --bind all --cache-size 2048 >/dev/null
  fi
}

check_adb() {
  require_command adb
  adb start-server >/dev/null

  local device_count
  device_count="$(adb devices | awk 'NR > 1 && $2 == "device" {count++} END {print count + 0}')"
  if [ "$device_count" -eq 0 ]; then
    log "WARNING: no authorized Android device is connected; STF will still start"
  else
    log "ADB sees $device_count authorized Android device(s)"
  fi
}

start_stf() {
  local stf_bin

  require_command stf
  stf_bin="$(command -v stf)"
  stop_launch_service "$STF_LAUNCH_LABEL" "STF"
  assert_port_available "$STF_PORT" "STF"

  : >"$STF_LOG_FILE"
  log "Starting STF with launchctl"
  launchctl submit \
    -l "$STF_LAUNCH_LABEL" \
    -o "$STF_LOG_FILE" \
    -e "$STF_LOG_FILE" \
    -- /usr/bin/env PATH="$PATH" "$stf_bin" local --public-ip 127.0.0.1
  record_launch_pid "$STF_LAUNCH_LABEL" "$STF_PID_FILE"

  wait_for_http "STF" "http://127.0.0.1:$STF_PORT/" "$STF_LOG_FILE"
}

load_api_environment() {
  [ -f "$PROJECT_DIR/.env" ] || return 1

  set -a
  # shellcheck disable=SC1091
  . "$PROJECT_DIR/.env"
  set +a

  [ -n "${STF_TOKEN:-}" ] || return 1
  [ "${STF_TOKEN:-}" != "replace-with-local-token" ] || return 1

  STF_BASE_URL="${STF_BASE_URL:-http://127.0.0.1:7100}"
  MOBILE_MATRIX_PORT="${MOBILE_MATRIX_PORT:-$DEFAULT_API_PORT}"
  if [ "$MOBILE_MATRIX_PORT" = "7120" ]; then
    MOBILE_MATRIX_PORT="$DEFAULT_API_PORT"
  fi
  export STF_BASE_URL MOBILE_MATRIX_PORT
  return 0
}

start_api_if_configured() {
  if ! load_api_environment; then
    log "Skipping the experimental API: .env has no valid STF_TOKEN"
    return 0
  fi

  stop_launch_service "$API_LAUNCH_LABEL" "Mobile Matrix API"
  assert_port_available "$MOBILE_MATRIX_PORT" "Mobile Matrix API"

  log "Building Mobile Matrix API"
  npm run build >/dev/null

  : >"$API_LOG_FILE"
  log "Starting Mobile Matrix API with launchctl"
  launchctl submit \
    -l "$API_LAUNCH_LABEL" \
    -o "$API_LOG_FILE" \
    -e "$API_LOG_FILE" \
    -- /usr/bin/env \
      PATH="$PATH" \
      STF_BASE_URL="$STF_BASE_URL" \
      STF_TOKEN="$STF_TOKEN" \
      MOBILE_MATRIX_PORT="$MOBILE_MATRIX_PORT" \
      node "$PROJECT_DIR/dist/src/main.js"
  record_launch_pid "$API_LAUNCH_LABEL" "$API_PID_FILE"

  wait_for_http \
    "Mobile Matrix API" \
    "http://127.0.0.1:$MOBILE_MATRIX_PORT/health" \
    "$API_LOG_FILE"
}

main() {
  activate_node20
  require_command curl
  start_colima
  restart_rethinkdb
  check_adb
  start_stf
  start_api_if_configured

  log "Startup complete"
  log "STF console: http://127.0.0.1:$STF_PORT/"
  if [ -f "$API_PID_FILE" ]; then
    log "Mobile Matrix API: http://127.0.0.1:$MOBILE_MATRIX_PORT/health"
  fi
  log "Logs: $LOG_DIR"
}

main "$@"
