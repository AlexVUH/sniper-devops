#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Configs e libs
source "${ROOT_DIR}/conf/sniper.conf"
source "${ROOT_DIR}/conf/blacklist.conf"
source "${ROOT_DIR}/lib/core.sh"
source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/validate.sh"
source "${ROOT_DIR}/lib/utils.sh"

core_setup_colors
require_root

# Lock agora ocorre após garantir root (evita Permission denied em /tmp)
core_acquire_lock

# Remove --debug dos parâmetros (como no original)
ARGS=()
for arg in "$@"; do
  [[ "$arg" != "--debug" ]] && ARGS+=("$arg")
done

ACTION="${ARGS[0]:-}"
IP="${ARGS[1]:-}"
CMD="${ARGS[2]:-}"
ARGS_LEN=${#ARGS[@]}

# HELP do módulo → delega para o help raiz, para manter 100% idêntico
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

# 🔹 Log de parâmetros no módulo (formato solicitado)
debug "Parâmetros: ACTION=${ACTION:-<vazio>} IP=${IP:-<vazio>} CMD=${CMD:-<vazio>}"

# Helper: só imprime a mensagem colorida se NÃO estiver em DEBUG
maybe_echo() {
  local msg="$1"
  if [[ "${DEBUG:-0}" != "1" ]]; then
    echo -e "$msg"
  fi
}

# Guardamos o terceiro argumento bruto (antes de normalizar) para detectar extras
RAW_THIRD="${ARGS[2]:-}"

# Se ACTION foi 'list' ou 'flush' (via dispatcher: fw list [extra]) → rejeita extra
if [[ "$IP" == "list" || "$IP" == "flush" ]]; then
  if [[ -n "${RAW_THIRD:-}" ]]; then
    RESULT_MSG="Uso inválido: 'list' e 'flush' não aceitam parâmetros (ex.: use 'sniper.sh fw ${IP}')"
    debug "$RESULT_MSG"
    if [[ "${DEBUG:-0}" != "1" ]]; then
      maybe_echo "${RED}$RESULT_MSG${RESET}"
    fi
    exit 2
  fi
  CMD="$IP"
  IP=""
fi

# ❗ Também proíbe 'list' e 'flush' quando vierem como CMD com IP preenchido (fw 1.2.3.4 list)
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

    # IP/CIDR inválido → DEBUG + exit 2
    if ! is_valid_ip_or_cidr "$IP"; then
      RESULT_MSG="Erro: IP ou CIDR inválido: $IP"
      debug "$RESULT_MSG"
      maybe_echo "${RED}$RESULT_MSG${RESET}"
      exit 2
    fi

    # Garante regra (mantido igual à sua lógica atual)
    ensure_iptables_rule

    if ipset test "$SET_NAME" "$IP" >/dev/null 2>&1; then
      RESULT_MSG="$IP já está bloqueado"
      debug "$RESULT_MSG"
      maybe_echo "${YELLOW}$RESULT_MSG${RESET}"
      # ✅ LogCenter: registrar tentativa idempotente
      log_event "add" "$IP" "already_blocked" "$TIMEOUT"
      exit 4
    fi

    debug "ipset add $SET_NAME $IP timeout $TIMEOUT"
    if ! ipset add "$SET_NAME" "$IP" timeout "$TIMEOUT" 2>/dev/null; then
      RESULT_MSG="Falha ao adicionar $IP ao set $SET_NAME"
      debug "$RESULT_MSG"
      maybe_echo "${RED}$RESULT_MSG${RESET}"
      # (Opcional) log_event "add" "$IP" "error" "$TIMEOUT"
      exit 1
    fi

    # Logs locais (compat)
    log_block "$IP"

    RESULT_MSG="$IP bloqueado com sucesso"
    debug "$RESULT_MSG"
    maybe_echo "${GREEN}$RESULT_MSG${RESET}"

    # ✅ LogCenter: somente ADD bem-sucedido
    log_event "add" "$IP" "blocked" "$TIMEOUT"
    ;;

  del)
    check_ipset_exists || exit 3

    if ! is_valid_ip_or_cidr "$IP"; then
      RESULT_MSG="Erro: IP ou CIDR inválido: $IP"
      debug "$RESULT_MSG"
      maybe_echo "${RED}$RESULT_MSG${RESET}"
      exit 2
    fi

    # Revalida se ainda está bloqueado (pode ter expirado entre checagens)
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
      # Modo DEBUG: uma linha [DEBUG] por membro (com timeout)
      mapfile -t _members < <(ipset list "$SET_NAME" | awk '/Members:/{flag=1; next} flag && NF {print}')
      for _m in "${_members[@]}"; do
        debug "$_m"
      done
    else
      # Modo normal: imprimir a linha completa (inclui timeout), sem headers
      ipset list "$SET_NAME" \
        | awk '/Members:/{flag=1; next} flag && NF {print}'
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
