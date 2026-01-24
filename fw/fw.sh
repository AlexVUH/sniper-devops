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

Flags:
  --autoblock    Marca a inclusão como automática (ex.: cron)
                 Ex.: sniper.sh fw 8.8.8.0/24 add --autoblock

  --force        Força a inclusão mesmo que o IP/CIDR esteja na whitelist.
                 Use com extremo cuidado. Evento será auditado como override.
                 Ex.: sniper.sh fw 172.64.1.2 add --force

Exit codes:
  0  Sucesso
  1  Erro genérico
  2  Uso inválido / IP/CIDR inválido / parâmetros indevidos
  3  ipset inexistente
  4  IP já bloqueado
  5  IP não está bloqueado
  6  Barrado pela whitelist (blocked_by_whitelist)
EOF
}

# ------------------------------------------------------------------
# Normalização de argumentos: remove --debug, --autoblock, --force
# ------------------------------------------------------------------
DEBUG_PRESENT=0
AUTOBLOCK_PRESENT=0
FORCE_PRESENT=0
CLEAN_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --debug)      DEBUG_PRESENT=1 ;;
    --autoblock)  AUTOBLOCK_PRESENT=1 ;;
    --force)      FORCE_PRESENT=1 ;;
    *)            CLEAN_ARGS+=("$arg") ;;
  esac
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

# Exporta flags para o módulo
[[ "$DEBUG_PRESENT"     -eq 1 ]] && DEBUG=1     && export DEBUG
[[ "$AUTOBLOCK_PRESENT" -eq 1 ]] && AUTOBLOCK=1 && export AUTOBLOCK
[[ "$FORCE_PRESENT"     -eq 1 ]] && FORCE=1     && export FORCE

# Mapeamento para list/flush
DEST_ACTION="fw"
if [[ "$ACTION" == "list" || "$ACTION" == "flush" ]]; then
  DEST_IP=""
  DEST_CMD="$ACTION"
else
  DEST_IP="$ACTION"
  DEST_CMD="$IP"
fi

# DEBUG do dispatcher (omite IP em list/flush)
if [[ "$DEST_CMD" == "list" || "$DEST_CMD" == "flush" ]]; then
  debug "Parâmetros: ACTION=${DEST_ACTION:-<vazio>} CMD=${DEST_CMD:-<vazio>}"
else
  debug "Parâmetros: ACTION=${DEST_ACTION:-<vazio>} IP=${DEST_IP:-<vazio>} CMD=${DEST_CMD:-<vazio>}"
fi

# Validação imediata: list/flush sem extras
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
exec "${ROOT_DIR}/fw/blacklist.sh" "$DEST_ACTION" "$DEST_IP" "$DEST_CMD"
