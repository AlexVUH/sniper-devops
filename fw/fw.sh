#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Carrega base
source "${ROOT_DIR}/conf/sniper.conf"
source "${ROOT_DIR}/lib/core.sh"
source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/validate.sh"
source "${ROOT_DIR}/lib/utils.sh"

# Habilita cores
core_setup_colors

help_msg_fw() {
  cat <<'EOF'
Uso:
  sniper.sh fw <IP|CIDR> add
  sniper.sh fw <IP|CIDR> del
  sniper.sh fw <IP|CIDR> check
  sniper.sh fw list
  sniper.sh fw flush
  sniper.sh fw help
  sniper.sh fw --debug <comando>
EOF
}

# ------------------------------------------------------------------
# Normalização de argumentos: remove --debug localmente
# ------------------------------------------------------------------
DEBUG_PRESENT=0
CLEAN_ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--debug" ]]; then
    DEBUG_PRESENT=1
  else
    CLEAN_ARGS+=("$arg")
  fi
done

# Reatribui os parâmetros limpos para facilitar o parsing
set -- "${CLEAN_ARGS[@]}"

ACTION="${1:-help}"
IP="${2:-}"
CMD="${3:-}"

# Se for help (ou vazio), delega para o help raiz — sem ativar DEBUG
if [[ "$ACTION" == "help" || -z "$ACTION" ]]; then
  exec "${ROOT_DIR}/sniper.sh" help
fi

# Se NÃO é help, aí sim ativamos/exportamos DEBUG (se --debug estava presente)
[[ "$DEBUG_PRESENT" -eq 1 ]] && DEBUG=1 && export DEBUG

# 🔹 Log do dispatcher no formato encaminhado (opcional)
DEST_ACTION="fw"
DEST_IP="${ACTION:-}"
DEST_CMD="${IP:-}"
debug "Parâmetros: ACTION=${DEST_ACTION:-<vazio>} IP=${DEST_IP:-<vazio>} CMD=${DEST_CMD:-<vazio>}"

# ❗ Validação imediata: list/flush NÃO aceitam argumentos extras
if [[ "$ACTION" == "list" || "$ACTION" == "flush" ]]; then
  if [[ -n "${IP:-}" ]]; then
    MSG="Uso inválido: 'list' e 'flush' não aceitam parâmetros (ex.: use 'sniper.sh fw $ACTION')"
    debug "$MSG"
    if [[ "${DEBUG:-0}" != "1" ]]; then
      echo -e "${RED}$MSG${RESET}"
    fi
    exit 2
  fi
fi

# Encaminha para a implementação:
#   1º arg: ACTION="fw"
#   2º arg: IP (pode ser <IP|CIDR>, "list" ou "flush")
#   3º arg: CMD (ex.: add|del|check) — quando existir
exec "${ROOT_DIR}/fw/blacklist.sh" "fw" "$ACTION" "$IP"
