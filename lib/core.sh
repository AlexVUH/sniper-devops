#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Trap de erro simples
trap 'echo -e "Erro na linha $LINENO"; exit 1' ERR

# Cores (iguais ao original, controladas por NO_COLOR)
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; CYAN="\e[36m"; RESET="\e[0m"

# Debug default e por env/flag
DEBUG="${DEBUG:-0}"
if [[ "${BLOCKZ_DEBUG:-0}" == "1" ]]; then DEBUG=1; fi

core_setup_colors() {
  if [[ "${NO_COLOR:-0}" == "1" || ! -t 1 ]]; then
    GREEN=""; YELLOW=""; RED=""; BLUE=""; CYAN=""; RESET=""
  fi
}

# Debug no formato solicitado: [DEBUG][YYYY-MM-DD HH:MM:SS] Mensagem
debug() {
  if [ "${DEBUG:-0}" -eq 1 ]; then
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[DEBUG][%s] %s\n' "$ts" "$*"
  fi
}

core_acquire_lock() {
  # Garante diretório de logs para mensagem de "já está rodando"
  mkdir -p "${LOG_DIR}"

  exec 200>"${LOCK_FILE}" || exit 1
  if ! flock -n 200; then
    echo "$(date '+%F %T') ${APP_NAME} já está rodando" >> "${LOG_TXT}"
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
