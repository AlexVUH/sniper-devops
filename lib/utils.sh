#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

check_ipset_exists() {
  if ! ipset list "$SET_NAME" >/dev/null 2>&1; then
    debug "ipset $SET_NAME não existe"
    echo -e "${YELLOW}Aviso: ipset \"$SET_NAME\" não existe${RESET}"
    echo "Crie com:"
    echo "ipset create $SET_NAME hash:net timeout $TIMEOUT"
    return 1
  fi
  debug "ipset $SET_NAME existe"
  return 0
}

ensure_iptables_rule() {
  if ! iptables -C "${IPTABLES_CHAIN}" -m set --match-set "$SET_NAME" src -j DROP 2>/dev/null; then
    debug "Regra iptables não encontrada, criando"
    iptables -I "${IPTABLES_CHAIN}" -m set --match-set "$SET_NAME" src -j DROP
  else
    debug "Regra iptables já existe"
  fi
}
