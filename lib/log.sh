#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

log_block() {
  local ip="$1"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "${LOG_DIR}"

  echo "$ts $ip" >> "${LOG_TXT}"
  echo "{\"datetime\":\"$ts\",\"ip\":\"$ip\"}" >> "${LOG_JSON}"

  debug "Log registrado para $ip"
}
