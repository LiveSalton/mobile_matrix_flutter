#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_DIR="$PROJECT_DIR/.runtime"
LOG_DIR="$RUNTIME_DIR/logs"
PID_DIR="$RUNTIME_DIR/pids"
STF_PID_FILE="$PID_DIR/stf.pid"
STF_LOG_FILE="$LOG_DIR/stf.log"
RETHINKDB_DIR="$RUNTIME_DIR/rethinkdb"
RETHINKDB_CONTAINER="mobile-matrix-rethinkdb"
STF_LAUNCH_LABEL="com.mobile-matrix.stf"
STF_PORT=7100
STF_DIR="$PROJECT_DIR/vendor/devicefarmer-stf"
STF_BIN="$STF_DIR/bin/stf"
NODE20_BIN="${MOBILE_MATRIX_NODE20_BIN:-/Users/salton/.nvm/versions/node/v20.19.6/bin}"
AIRTEST_VENV_DIR="$RUNTIME_DIR/airtest-venv"
AIRTEST_PYTHON="${MOBILE_MATRIX_AIRTEST_PYTHON:-$AIRTEST_VENV_DIR/bin/python}"
AIRTEST_EVIDENCE_DIR="$RUNTIME_DIR/airtest-evidence"
AIRTEST_BOOTSTRAP_PYTHON="${MOBILE_MATRIX_AIRTEST_BOOTSTRAP_PYTHON:-/Users/salton/.local/bin/python3.12}"
UV_BIN="${MOBILE_MATRIX_UV_BIN:-/Users/salton/.local/bin/uv}"

mkdir -p "$LOG_DIR" "$PID_DIR" "$RETHINKDB_DIR" "$AIRTEST_EVIDENCE_DIR"
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

stop_vendored_stf_process() {
  local pid
  local command_line

  pid="$(port_listener_pid "$STF_PORT")"
  [ -z "$pid" ] && return 0

  command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  case "$command_line" in
    *"$STF_DIR/lib/cli poorxy"*)
      log "Stopping previous vendored STF process PID $pid"
      kill "$pid" >/dev/null 2>&1 || true
      sleep 1
      ;;
  esac
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

prepare_airtest() {
  if [ -x "$AIRTEST_PYTHON" ] && "$AIRTEST_PYTHON" -c 'import airtest' >/dev/null 2>&1; then
    log "Airtest runtime is ready: $AIRTEST_PYTHON"
    return 0
  fi

  [ "$AIRTEST_PYTHON" = "$AIRTEST_VENV_DIR/bin/python" ] || fail \
    "Configured Airtest runtime cannot import airtest: $AIRTEST_PYTHON"
  [ -x "$UV_BIN" ] || fail "uv is required to prepare Airtest. Set MOBILE_MATRIX_UV_BIN."
  [ -x "$AIRTEST_BOOTSTRAP_PYTHON" ] || fail \
    "Python 3.12 is required to prepare Airtest. Set MOBILE_MATRIX_AIRTEST_BOOTSTRAP_PYTHON."

  log "Preparing isolated Airtest runtime"
  "$UV_BIN" venv --python "$AIRTEST_BOOTSTRAP_PYTHON" "$AIRTEST_VENV_DIR" >/dev/null
  "$UV_BIN" pip install --python "$AIRTEST_PYTHON" 'airtest==1.3.6' >/dev/null
}

start_stf() {
  [ -x "$STF_BIN" ] || fail "Vendored STF is missing: $STF_BIN"
  stop_launch_service "$STF_LAUNCH_LABEL" "STF"
  stop_vendored_stf_process
  assert_port_available "$STF_PORT" "STF"

  : >"$STF_LOG_FILE"
  log "Starting STF with launchctl"
  launchctl submit \
    -l "$STF_LAUNCH_LABEL" \
    -o "$STF_LOG_FILE" \
    -e "$STF_LOG_FILE" \
    -- /usr/bin/env PATH="$PATH" AIRTEST_PYTHON="$AIRTEST_PYTHON" \
      AIRTEST_EVIDENCE_DIR="$AIRTEST_EVIDENCE_DIR" \
      STF_PROVIDER_SCREEN_GRABBER=minicap-apk "$STF_BIN" local \
      --public-ip 127.0.0.1 \
      --trusted-local \
      --local-user-name administrator \
      --local-user-email administrator@fakedomain.com
  record_launch_pid "$STF_LAUNCH_LABEL" "$STF_PID_FILE"

  wait_for_http "STF" "http://127.0.0.1:$STF_PORT/" "$STF_LOG_FILE"
}

prepare_stf() {
  [ -d "$STF_DIR/node_modules" ] || {
    log "Installing vendored STF dependencies"
    (cd "$STF_DIR" && npm install)
  }

  [ -d "$STF_DIR/res/bower_components" ] || {
    log "Installing vendored STF web dependencies"
    (cd "$STF_DIR" && ./node_modules/.bin/bower install)
  }

  [ -f "$STF_DIR/res/build/entry/app.entry.js" ] || {
    log "Building vendored STF web console"
    (cd "$STF_DIR" && ./node_modules/.bin/gulp build)
  }
}

main() {
  activate_node20
  require_command curl
  start_colima
  restart_rethinkdb
  check_adb
  prepare_airtest
  prepare_stf
  stop_launch_service "com.mobile-matrix.api" "legacy Mobile Matrix API"
  start_stf

  log "Startup complete"
  log "STF console: http://127.0.0.1:$STF_PORT/"
  log "Logs: $LOG_DIR"
}

main "$@"
