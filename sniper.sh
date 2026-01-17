#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Descobre diretório raiz do projeto
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

# Carrega configs e libs
source "${ROOT_DIR}/conf/sniper.conf"
source "${ROOT_DIR}/lib/core.sh"
source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/validate.sh"
source "${ROOT_DIR}/lib/utils.sh"

# Limpa --debug ANTES de decidir help
DEBUG_PRESENT=0
CLEAN_ARGS=()
for arg in "$@"; do
  [[ "$arg" == "--debug" ]] && DEBUG_PRESENT=1 || CLEAN_ARGS+=("$arg")
done
set -- "${CLEAN_ARGS[@]}"

ACTION="${1:-help}"
shift || true

# HELP COMPLETO DO CLI RAIZ
help_msg_root() {
  cat <<'EOF'
sniper-devops – CLI

Uso principal:
  ./sniper.sh fw <IP|CIDR> add
  ./sniper.sh fw <IP|CIDR> del
  ./sniper.sh fw <IP|CIDR> check
  ./sniper.sh fw list
  ./sniper.sh fw flush
  ./sniper.sh help

Modo debug (mostra apenas linhas [DEBUG]):
  ./sniper.sh fw --debug <comando>

────────────────────────────────────────────────────────────────────

PRÉ-REQUISITOS PARA O MÓDULO FIREWALL (fw)
Antes de usar qualquer comando da blacklist, execute:

1) Criar o IPSET:
     sudo ipset create blacklist hash:net timeout 1800

2) Criar a regra do IPTABLES (bloquear IPs do set blacklist):
     sudo iptables -I INPUT -m set --match-set blacklist src -j DROP

➜ Remover a regra:
     sudo iptables -D INPUT -m set --match-set blacklist src -j DROP

➜ Listar conteúdos do set:
     sudo ipset list blacklist

➜ Limpar (sem destruir) o set:
     sudo ipset flush blacklist

EOF
}

# Se o usuário pediu help → mostra sem debug
if [[ "$ACTION" == "help" ]]; then
  help_msg_root
  exit 0
fi

# Se NÃO pediu help → ativa DEBUG (se necessário)
[[ "$DEBUG_PRESENT" -eq 1 ]] && DEBUG=1 && export DEBUG

core_setup_colors

case "$ACTION" in
  fw) exec "${ROOT_DIR}/fw/fw.sh" "$@" ;;
  *)
    echo -e "${RED}Erro: comando inválido \"$ACTION\"${RESET}"
    help_msg_root
    exit 2
    ;;
esac
