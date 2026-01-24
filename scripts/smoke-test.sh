#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# sniper-devops – Smoke Test
# Executa uma bateria de testes automatizados para validar o módulo FW
# Requisitos: sudo, ipset, jq, iptables
# -----------------------------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPER="$ROOT_DIR/sniper.sh"
CONF="$ROOT_DIR/conf/sniper.conf"
WHITELIST_JSON=""

# Cores leves (apenas para saída humana; em CI ficam sem cor se redirecionado)
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; RESET="\e[0m"
if [[ ! -t 1 ]]; then GREEN=""; YELLOW=""; RED=""; BLUE=""; RESET=""; fi

PASS_CNT=0
FAIL_CNT=0
TOTAL_CNT=0

print_header() {
  echo -e "${BLUE}sniper-devops – Smoke Test${RESET}"
  echo "ROOT_DIR: $ROOT_DIR"
  echo "SNIPER  : $SNIPER"
  echo
}

require() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${RED}Falta dependência: ${cmd}${RESET}"
    exit 1
  fi
}

ensure_ipset() {
  # Lê SET_NAME/TIMEOUT do conf
  # shellcheck disable=SC1090
  source "$CONF"
  if ! ipset list "$SET_NAME" >/dev/null 2>&1; then
    echo -e "${YELLOW}Criando ipset '$SET_NAME' (timeout=${TIMEOUT:-1800})${RESET}"
    sudo ipset create "$SET_NAME" hash:net timeout "${TIMEOUT:-1800}"
  fi
}

load_conf_vars() {
  # shellcheck disable=SC1090
  source "$CONF"
  export SET_NAME TIMEOUT WHITELIST_ENABLED WHITELIST_JSON
}

run_test() {
  local desc="$1"; shift
  local expected_rc="$1"; shift
  local expect_substr="${1-}"; shift || true   # <-- sempre shift, mesmo vazio
  local cmd=("$@")

  TOTAL_CNT=$((TOTAL_CNT+1))
  echo -e "\n${BLUE}[$TOTAL_CNT]${RESET} $desc"
  echo "CMD: ${cmd[*]}"

  set +e
  local out
  out=$("${cmd[@]}" 2>&1)
  local rc=$?
  set -e

  echo "$out"
  echo "RC: $rc (esperado: $expected_rc)"

  local ok=1
  [[ "$rc" -eq "$expected_rc" ]] || ok=0
  if [[ -n "$expect_substr" ]] && ! grep -q -- "$expect_substr" <<<"$out"; then ok=0; fi

  if [[ $ok -eq 1 ]]; then
    echo -e "${GREEN}PASS${RESET}"
    PASS_CNT=$((PASS_CNT+1))
  else
    echo -e "${RED}FAIL${RESET}"
    FAIL_CNT=$((FAIL_CNT+1))
  fi
}

maybe_run() {
  # Executa um teste opcional apenas se um padrão existir no whitelist.json
  local desc="$1"; shift
  local cidr_pattern="$1"; shift
  local expected_rc="$1"; shift
  local expect_substr="${1-}"; shift || true
  local cmd=("$@")

  if [[ -n "$WHITELIST_JSON" ]] && jq -e ".ipv4[] | select(.cidr == \"${cidr_pattern}\")" "$WHITELIST_JSON" >/dev/null 2>&1; then
    run_test "$desc" "$expected_rc" "$expect_substr" "${cmd[@]}"
  else
    echo -e "\n${YELLOW}[skip]${RESET} $desc — CIDR '${cidr_pattern}' não encontrado em $WHITELIST_JSON"
  fi
}

main() {
  print_header

  # Pré-requisitos
  require jq
  require ipset
  require iptables

  if [[ ! -f "$SNIPER" ]]; then
    echo -e "${RED}Arquivo não encontrado: $SNIPER${RESET}"
    exit 1
  fi
  if [[ ! -f "$CONF" ]]; then
    echo -e "${RED}Arquivo não encontrado: $CONF${RESET}"
    exit 1
  fi

  load_conf_vars
  ensure_ipset

  # Validar whitelist (se habilitada)
  if [[ "${WHITELIST_ENABLED:-0}" == "1" ]]; then
    if [[ -z "${WHITELIST_JSON:-}" || ! -f "$WHITELIST_JSON" ]]; then
      echo -e "${RED}WHITELIST habilitada, mas arquivo ausente: '$WHITELIST_JSON'${RESET}"
      exit 1
    fi
    if ! jq -e . "$WHITELIST_JSON" >/dev/null 2>&1; then
      echo -e "${RED}JSON inválido: $WHITELIST_JSON${RESET}"
      exit 1
    fi
    echo -e "Whitelist: habilitada (${WHITELIST_JSON})"
  else
    echo -e "Whitelist: desabilitada"
  fi

  # ---------- TESTES ----------

  # 1) list --debug (RC=0)
  run_test "fw list (DEBUG)" 0 "Parâmetros: ACTION=fw CMD=list" \
    "$SNIPER" fw --debug list

  # 2) flush --debug (RC=0)
  run_test "fw flush (DEBUG)" 0 "Parâmetros: ACTION=fw CMD=flush" \
    "$SNIPER" fw --debug flush

  # 3) list com parâmetro extra (RC=2)
  run_test "fw list 8.8.8.8 (inválido)" 2 "Uso inválido" \
    "$SNIPER" fw list 8.8.8.8

  # 4) fw 8.8.8.8 list (RC=2)
  run_test "fw 8.8.8.8 list (inválido)" 2 "Uso inválido" \
    "$SNIPER" fw 8.8.8.8 list

  # Prepara ambiente limpo para 8.8.8.8
  set +e; sudo "$SNIPER" fw 8.8.8.8 del >/dev/null 2>&1; set -e

  # 5) ADD permitido (RC=0)
  run_test "fw 8.8.8.8 add (permitido)" 0 "bloqueado com sucesso" \
    sudo "$SNIPER" fw --debug 8.8.8.8 add

  # 6) ADD idempotente (RC=4)
  run_test "fw 8.8.8.8 add (idempotente)" 4 "já está bloqueado" \
    sudo "$SNIPER" fw --debug 8.8.8.8 add

  # 7) CHECK bloqueado (RC=0)
  run_test "fw 8.8.8.8 check (bloqueado)" 0 "está bloqueado" \
    sudo "$SNIPER" fw --debug 8.8.8.8 check

  # 8) DEL bloqueado (RC=0)
  run_test "fw 8.8.8.8 del (remover)" 0 "removido do bloqueio" \
    sudo "$SNIPER" fw --debug 8.8.8.8 del

  # 9) DEL não bloqueado (RC=5)
  run_test "fw 8.8.8.8 del (não bloqueado)" 5 "não está bloqueado" \
    sudo "$SNIPER" fw --debug 8.8.8.8 del

  # 10) IP/CIDR inválido (RC=2)
  run_test "fw 8.8.8.257 add (inválido)" 2 "Erro: IP ou CIDR inválido" \
    "$SNIPER" fw --debug 8.8.8.257 add

  # 11) Whitelist RFC1918 sem --force (RC=6)
  if [[ "${WHITELIST_ENABLED:-0}" == "1" ]]; then
    run_test "fw 10.1.2.3 add (whitelist RFC1918)" 6 "IP não permitido (motivo: RFC1918)" \
      sudo "$SNIPER" fw --debug 10.1.2.3 add
  fi

  # 12) Whitelist com --force (RC=0) e depois remover (RC=0)
  if [[ "${WHITELIST_ENABLED:-0}" == "1" ]]; then
    run_test "fw 10.1.2.3 add --force (override)" 0 "bloqueado com sucesso" \
      sudo "$SNIPER" fw --debug 10.1.2.3 add --force
    run_test "fw 10.1.2.3 del (limpeza)" 0 "removido do bloqueio" \
      sudo "$SNIPER" fw --debug 10.1.2.3 del
  fi

  # 13) Cloudflare (se existir no JSON) – RC=6
  if [[ "${WHITELIST_ENABLED:-0}" == "1" ]]; then
    maybe_run "fw 172.64.1.2 add (Cloudflare)" "172.64.0.0/13" 6 "Cloudflare" \
      sudo "$SNIPER" fw --debug 172.64.1.2 add
  fi

  # 14) Zscaler (se existir no JSON) – exemplo 170.85.0.0/16
  if [[ "${WHITELIST_ENABLED:-0}" == "1" ]]; then
    maybe_run "fw 170.85.0.10 add (Zscaler)" "170.85.0.0/16" 6 "Zscaler" \
      sudo "$SNIPER" fw --debug 170.85.0.10 add
  fi

  # 15) list normal (sem DEBUG) – apenas executa (RC=0)
  run_test "fw list (normal)" 0 "" \
    "$SNIPER" fw list

  # 16) flush final (RC=0)
  run_test "fw flush (final)" 0 "Blacklist esvaziada" \
    "$SNIPER" fw flush

  echo -e "\n${BLUE}Resumo:${RESET} Total=$TOTAL_CNT | ${GREEN}PASS=$PASS_CNT${RESET} | ${RED}FAIL=$FAIL_CNT${RESET}"
  [[ "$FAIL_CNT" -eq 0 ]] || exit 1
}

main "$@"
