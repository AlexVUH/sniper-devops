#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Mantém o log simples (LEGADO) apenas no TXT para evitar duplicidade no JSON
log_block() {
  local ip="$1"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "${LOG_DIR}"

  # Apenas TXT legado
  echo "$ts $ip" >> "${LOG_TXT}"

  debug "Log registrado (TXT legado) para $ip"
}

# Evento estruturado (JSON Lines) para LogCenter
# OBS: Apenas 'add' deve gerar evento — reforçado aqui por segurança.
log_event() {
  # Uso: log_event <action> <ip> <result> [timeout_sec]
  local action="$1" ip="$2" result="$3" timeout="$4"

  # Somente ADD → envia ao LogCenter
  if [[ "$action" != "add" ]]; then
    debug "log_event ignorado (action=$action) — apenas 'add' é enviado ao LogCenter"
    return 0
  fi

  local ts_local host
  # Formato solicitado: "datetime":"2026-01-17 02:58:18"
  ts_local="$(date '+%Y-%m-%d %H:%M:%S')"
  host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown)"

  # JSON compacto em uma única linha, com 'datetime' no formato pedido
  local json
  json="{\"datetime\":\"$ts_local\", \"action\":\"$action\", \"ip\":\"$ip\", \"set\":\"$SET_NAME\", \"result\":\"$result\", \"host\":\"$host\", \"env\":\"${ENVIRONMENT:-unknown}\", \"script\":\"sniper-devops\", \"script_version\":\"${SCRIPT_VERSION:-unknown}\", \"schema\":\"1\""
  if [[ -n "$timeout" ]]; then
    json="$json, \"timeout_sec\": $timeout"
  fi
  json="$json}"

  mkdir -p "${LOG_DIR}"
  echo "$json" >> "${LOG_JSON}"
  debug "Evento enviado ao LogCenter (via arquivo): action=$action ip=$ip result=$result"
}
