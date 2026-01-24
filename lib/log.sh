#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Mantém o log simples (LEGADO) apenas no TXT para evitar duplicidade no JSON
log_block() {
  local ip="$1"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "${LOG_DIR}"
  echo "$ts $ip" >> "${LOG_TXT}"
  debug "Log registrado (TXT legado) para $ip"
}

# Evento estruturado (JSON Lines) para LogCenter
# Uso: log_event <action> <ip> <result> [timeout_sec] [source] [user] [whitelist_override] [previous_whitelist_reason]
log_event() {
  # Tolerante a set -u:
  local action="${1-}" ip="${2-}" result="${3-}" timeout="${4-}" source="${5-}" user="${6-}" wl_override="${7-}" prev_reason="${8-}"

  # Mínimos
  if [[ -z "${action}" || -z "${ip}" || -z "${result}" ]]; then
    debug "log_event ignorado: parâmetros obrigatórios ausentes (action='$action' ip='$ip' result='$result')"
    return 0
  fi

  # Apenas 'add' vai para o LogCenter
  if [[ "$action" != "add" ]]; then
    debug "log_event ignorado (action=$action) — apenas 'add' é enviado ao LogCenter"
    return 0
  fi

  local ts_utc host
  ts_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown)"

  # Defaults
  source="${source:-manual}"

  # Resolve usuário se não informado
  if [[ -z "${user}" ]]; then
    if [[ -n "${SUDO_USER:-}" ]]; then
      user="${SUDO_USER}"
    else
      user="$(id -un 2>/dev/null || logname 2>/dev/null || whoami 2>/dev/null || echo unknown)"
    fi
  fi

  # Boolean em JSON para override de whitelist
  local wl_override_json="false"
  if [[ "${wl_override}" == "1" || "${wl_override}" == "true" ]]; then
    wl_override_json="true"
  fi

  # Monta JSON (uma linha)
  local json
  json="{\"datetime\":\"$ts_utc\", \"action\":\"$action\", \"ip\":\"$ip\", \"set\":\"$SET_NAME\", \"result\":\"$result\", \"host\":\"$host\", \"env\":\"${ENVIRONMENT:-unknown}\", \"script\":\"sniper-devops\", \"script_version\":\"${SCRIPT_VERSION:-unknown}\", \"schema\": 1, \"source\":\"$source\", \"user\":\"$user\", \"whitelist_override\": ${wl_override_json}"
  if [[ -n "${timeout}" ]]; then
    json="$json, \"timeout_sec\": ${timeout}"
  fi
  if [[ -n "${prev_reason}" ]]; then
    # Escape básico de aspas (simples; para notas simples funciona bem)
    local safe_reason="${prev_reason//\"/\\\"}"
    json="$json, \"previous_whitelist_reason\": \"${safe_reason}\""
  fi
  json="$json}"

  mkdir -p "${LOG_DIR}"
  echo "$json" >> "${LOG_JSON}"
  debug "Evento enviado ao LogCenter: action=$action ip=$ip result=$result source=$source user=$user override=${wl_override_json} reason='${prev_reason}'"
}
