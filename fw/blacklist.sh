#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Configs e libs
source "${ROOT_DIR}/conf/sniper.conf"
# (blacklist.conf foi descontinuado para SET_NAME/TIMEOUT)
source "${ROOT_DIR}/lib/core.sh"
source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/validate.sh"
source "${ROOT_DIR}/lib/utils.sh"

core_setup_colors
require_root

# Lock agora ocorre após garantir root (evita Permission denied em /tmp)
core_acquire_lock

# Remove flags dos parâmetros e detecta --autoblock/--force local
ARGS=()
LOCAL_AUTOBLOCK=0
LOCAL_FORCE=0
for arg in "$@"; do
  case "$arg" in
    --debug)      ;; # já tratado
    --autoblock)  LOCAL_AUTOBLOCK=1 ;;
    --force)      LOCAL_FORCE=1 ;;
    *)            ARGS+=("$arg") ;;
  esac
done

# Fonte do bloqueio (manual/auto)
if [[ "${AUTOBLOCK:-0}" == "1" || "$LOCAL_AUTOBLOCK" -eq 1 ]]; then
  SOURCE="auto"
else
  SOURCE="manual"
fi

# Forçar inclusão mesmo contra whitelist?
if [[ "${FORCE:-0}" == "1" || "$LOCAL_FORCE" -eq 1 ]]; then
  FORCE_ACTIVE=1
else
  FORCE_ACTIVE=0
fi

ACTION="${ARGS[0]:-}"
IP="${ARGS[1]:-}"
CMD="${ARGS[2]:-}"
ARGS_LEN=${#ARGS[@]}

# HELP do módulo → delega para o help raiz
case "$ACTION" in
  help|"")
    exec "${ROOT_DIR}/sniper.sh" help
    ;;
  fw|"")
    ;;
  *)
    if [[ "${DEBUG:-0}" != "1" ]]; then
      echo -e "${RED}Erro: comando inválido \"$ACTION\"${RESET}"
    fi
    exit 2
    ;;
esac

# DEBUG de parâmetros (omite IP em list/flush)
if [[ "$CMD" == "list" || "$CMD" == "flush" ]]; then
  debug "Parâmetros: ACTION=${ACTION:-<vazio>} CMD=${CMD:-<vazio>}"
else
  debug "Parâmetros: ACTION=${ACTION:-<vazio>} IP=${IP:-<vazio>} CMD=${CMD:-<vazio>}"
fi

# Helper: só imprime mensagem colorida se NÃO estiver em DEBUG
maybe_echo() {
  local msg="$1"
  if [[ "${DEBUG:-0}" != "1" ]]; then
    echo -e "$msg"
  fi
}

# Normaliza list/flush indevidos com extra
RAW_THIRD="${ARGS[2]:-}"
if [[ "$IP" == "list" || "$IP" == "flush" ]]; then
  if [[ -n "${RAW_THIRD:-}" ]]; then
    RESULT_MSG="Uso inválido: 'list' e 'flush' não aceitam parâmetros (ex.: use 'sniper.sh fw ${IP}')"
    debug "$RESULT_MSG"
    if [[ "${DEBUG:-0}" != "1" ]]; then
      maybe_echo "${RED}$RESULT_MSG${RESET}"
    fi
    exit 2
  fi
  CMD="$IP"; IP=""
fi
if [[ "$CMD" == "list" || "$CMD" == "flush" ]]; then
  if [[ -n "${IP:-}" ]]; then
    RESULT_MSG="Uso inválido: 'list' e 'flush' não aceitam parâmetros (ex.: use 'sniper.sh fw ${CMD}')"
    debug "$RESULT_MSG"
    if [[ "${DEBUG:-0}" != "1" ]]; then
      maybe_echo "${RED}$RESULT_MSG${RESET}"
    fi
    exit 2
  fi
fi

case "$CMD" in
  add)
    check_ipset_exists || exit 3

    # IP/CIDR inválido
    if ! is_valid_ip_or_cidr "$IP"; then
      RESULT_MSG="Erro: IP ou CIDR inválido: $IP"
      debug "$RESULT_MSG"
      maybe_echo "${RED}$RESULT_MSG${RESET}"
      exit 2
    fi

    # ✅ WHITELIST: se ativo e NÃO forçado, barrar com exit 6
    WL_REASON=""
    if [[ "${WHITELIST_ENABLED:-0}" == "1" && "$FORCE_ACTIVE" -ne 1 ]]; then
      WL_REASON="$(whitelist_match_reason "$IP")"
      if [[ -n "$WL_REASON" ]]; then
        RESULT_MSG="IP não permitido (motivo: ${WL_REASON})"
        debug "$RESULT_MSG"
        maybe_echo "${BLUE}$RESULT_MSG${RESET}"
        exit 6   # <-- novo código dedicado a whitelist
      fi
    fi

    # Se --force, capturar motivo para auditoria (se houver)
    if [[ "$FORCE_ACTIVE" -eq 1 && "${WHITELIST_ENABLED:-0}" == "1" ]]; then
      [[ -z "$WL_REASON" ]] && WL_REASON="$(whitelist_match_reason "$IP")"
      if [[ -n "$WL_REASON" ]]; then
        debug "Forçando inclusão apesar da whitelist (motivo detectado: ${WL_REASON})"
      else
        debug "Forçando inclusão (sem motivo de whitelist detectado)"
      fi
    fi

    # Continua fluxo normal
    ensure_iptables_rule

    if ipset test "$SET_NAME" "$IP" >/dev/null 2>&1; then
      RESULT_MSG="$IP já está bloqueado"
      debug "$RESULT_MSG"
      maybe_echo "${YELLOW}$RESULT_MSG${RESET}"
      # LogCenter: tentativa idempotente (passa override e motivo)
      log_event "add" "$IP" "already_blocked" "$TIMEOUT" "$SOURCE" "" "$FORCE_ACTIVE" "$WL_REASON"
      exit 4
    fi

    debug "ipset add $SET_NAME $IP timeout $TIMEOUT"
    if ! ipset add "$SET_NAME" "$IP" timeout "$TIMEOUT" 2>/dev/null; then
      RESULT_MSG="Falha ao adicionar $IP ao set $SET_NAME"
      debug "$RESULT_MSG"
      maybe_echo "${RED}$RESULT_MSG${RESET}"
      # (Opcional) log_event "add" "$IP" "error" "$TIMEOUT" "$SOURCE" "" "$FORCE_ACTIVE" "$WL_REASON"
      exit 1
    fi

    # Log TXT legado
    log_block "$IP"

    RESULT_MSG="$IP bloqueado com sucesso"
    debug "$RESULT_MSG"
    maybe_echo "${GREEN}$RESULT_MSG${RESET}"

    # LogCenter: ADD bem-sucedido (passa override e motivo)
    log_event "add" "$IP" "blocked" "$TIMEOUT" "$SOURCE" "" "$FORCE_ACTIVE" "$WL_REASON"
    ;;

  del)
    check_ipset_exists || exit 3

    if ! is_valid_ip_or_cidr "$IP"; then
      RESULT_MSG="Erro: IP ou CIDR inválido: $IP"
      debug "$RESULT_MSG"
      maybe_echo "${RED}$RESULT_MSG${RESET}"
      exit 2
    fi

    if ! ipset test "$SET_NAME" "$IP" >/dev/null 2>&1; then
      RESULT_MSG="$IP não está bloqueado"
      debug "$RESULT_MSG"
      maybe_echo "${BLUE}$RESULT_MSG${RESET}"
      exit 5
    fi

    debug "ipset del $SET_NAME $IP"
    if ! ipset del "$SET_NAME" "$IP" 2>/dev/null; then
      RESULT_MSG="$IP não está bloqueado"
      debug "$RESULT_MSG"
      maybe_echo "${BLUE}$RESULT_MSG${RESET}"
      exit 5
    fi

    RESULT_MSG="$IP removido do bloqueio"
    debug "$RESULT_MSG"
    maybe_echo "${GREEN}$RESULT_MSG${RESET}"
    ;;

  check)
    check_ipset_exists || exit 3

    if ! is_valid_ip_or_cidr "$IP"; then
      RESULT_MSG="Erro: IP ou CIDR inválido: $IP"
      debug "$RESULT_MSG"
      maybe_echo "${RED}$RESULT_MSG${RESET}"
      exit 2
    fi

    if ipset test "$SET_NAME" "$IP" >/dev/null 2>&1; then
      RESULT_MSG="$IP está bloqueado"
      debug "$RESULT_MSG"
      maybe_echo "${GREEN}$RESULT_MSG${RESET}"
    else
      RESULT_MSG="$IP não está bloqueado"
      debug "$RESULT_MSG"
      maybe_echo "${BLUE}$RESULT_MSG${RESET}"
      exit 5
    fi
    ;;

  list)
    check_ipset_exists || exit 3
    if [[ "${DEBUG:-0}" == "1" ]]; then
      mapfile -t _members < <(ipset list "$SET_NAME" | awk '/Members:/{flag=1; next} flag && NF {print}')
      for _m in "${_members[@]}"; do
        debug "$_m"
      done
    else
      ipset list "$SET_NAME" | awk '/Members:/{flag=1; next} flag && NF {print}'
    fi
    ;;

  flush)
    check_ipset_exists || exit 3
    ipset flush "$SET_NAME"
    RESULT_MSG="Blacklist esvaziada"
    debug "$RESULT_MSG"
    maybe_echo "${GREEN}$RESULT_MSG${RESET}"
    ;;

  *)
    maybe_echo "${RED}Erro: comando inválido \"$CMD\"${RESET}"
    exit 2
    ;;
esac
