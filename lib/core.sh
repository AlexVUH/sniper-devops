
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Trap de erro simples
trap 'echo -e "Erro na linha $LINENO"; exit 1' ERR

# Cores (idênticas às do seu script)
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; CYAN="\e[36m"; RESET="\e[0m"

# Debug default e por env/flag (mantido)
DEBUG="${DEBUG:-0}"
if [[ "${sniper-devops_DEBUG:-0}" == "1" ]]; then DEBUG=1; fi

core_setup_colors() {
  if [[ "${NO_COLOR:-0}" == "1" || ! -t 1 ]]; then
    GREEN=""; YELLOW=""; RED=""; BLUE=""; CYAN=""; RESET=""
  fi
}

debug() {
  if [ "${DEBUG:-0}" -eq 1 ]; then
    echo -e "${CYAN}[DEBUG]${RESET}[${BLUE}$(date '+%F %T')${RESET}] $*"
  fi
}

core_acquire_lock() {
  exec 200>"${LOCK_FILE}" || exit 1
  if ! flock -n 200; then
    mkdir -p "${LOG_DIR}"
    echo "$(date '+%F %T') blockz já está rodando" >> "${LOG_TXT}"
    exit 0
  fi
}

require_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Erro: execute como root${RESET}"
    exit 1
  fi
  debug "Executando como root"
}
