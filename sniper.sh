
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

# Lock global: uma execução por vez
core_acquire_lock

# Suporte a --debug
for arg in "$@"; do
  [[ "$arg" == "--debug" ]] && DEBUG=1
done

core_setup_colors

usage() {
  cat <<EOF
${APP_NAME} – CLI
Uso:
  $0 fw <IP|CIDR> add|del|check
  $0 fw list
  $0 fw flush
  $0 help
EOF
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  help|-h|--help) usage; exit 0 ;;
  fw)  exec "${ROOT_DIR}/fw/fw.sh" "$@" ;;
  *)
    echo -e "${RED}Erro: comando inválido \"$ACTION\"${RESET}"
    exit 2
    ;;
esac
