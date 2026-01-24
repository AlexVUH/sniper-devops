#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# ------------------------------------------------------------------------------
# Validação sintática básica de IPv4 e CIDR (IPv4)
# Ex.: 8.8.8.8 | 192.168.0.0/16 | 10.0.0.0/8
# ------------------------------------------------------------------------------
is_valid_ip_or_cidr() {
  local input="$1"

  # Regex para IPv4 com /mask opcional
  if [[ ! "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?$ ]]; then
    return 1
  fi

  # Valida ranges 0..255 de cada octeto
  local ip="${input%%/*}"
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
  for octet in $o1 $o2 $o3 $o4; do
    if (( octet < 0 || octet > 255 )); then
      return 1
    fi
  done

  return 0
}

# ------------------------------------------------------------------------------
# Converte IPv4 dotted para inteiro não assinado 32-bit
# Ex.: 1.2.3.4 -> 16909060
# ------------------------------------------------------------------------------
ip_to_int() {
  local ip="$1"
  IFS='.' read -r a b c d <<< "$ip"
  # Proteção básica contra valores vazios ou inválidos
  : "${a:=0}" ; : "${b:=0}" ; : "${c:=0}" ; : "${d:=0}"
  echo $(( (a<<24) + (b<<16) + (c<<8) + d ))
}

# ------------------------------------------------------------------------------
# Dado um CIDR (IPv4), retorna o range "start end" como inteiros
# Aceita também IP sem máscara (trata como /32)
# ------------------------------------------------------------------------------
cidr_to_range() {
  local cidr="$1"
  local base mask

  if [[ "$cidr" == */* ]]; then
    base="${cidr%/*}"
    mask="${cidr#*/}"
  else
    base="$cidr"
    mask=32
  fi

  # Normaliza máscara
  if [[ -z "$mask" ]]; then
    mask=32
  fi

  local ip_int; ip_int="$(ip_to_int "$base")"
  local host_bits=$(( 32 - mask ))
  local size=$(( 1 << host_bits ))
  local start=$(( (ip_int >> host_bits) << host_bits ))
  local end=$(( start + size - 1 ))

  # IMPORTANTE: Mantemos "start end" separados por espaço
  echo "$start $end"
}

# ------------------------------------------------------------------------------
# Retorna 0 se IP ∈ CIDR (IPv4 only), senão 1
# Usa contexto aritmético (( ... )) e ajusta IFS para ler "start end"
# ------------------------------------------------------------------------------
ip_in_cidr() {
  local ip="$1"
  local cidr="$2"

  local ip_int start end
  ip_int="$(ip_to_int "$ip")" || return 1

  # IFS global no projeto é $'\n\t'; para ler "start end", usamos IFS=' ' localmente
  local OLDIFS="$IFS"
  IFS=' '
  read -r start end < <(cidr_to_range "$cidr") || {
    IFS="$OLDIFS"
    return 1
  }
  IFS="$OLDIFS"

  # Comparação numérica robusta
  if (( ip_int >= start && ip_int <= end )); then
    return 0
  else
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Lê o JSON de whitelist e retorna a "nota" do primeiro CIDR que contiver o IP.
# Caso não haja match ou whitelist esteja desativada/indisponível/JSON inválido,
# retorna string vazia.
#
# Requer: jq (se ausente, whitelist é ignorada silenciosamente, com debug externo)
# ------------------------------------------------------------------------------
whitelist_match_reason() {
  local ip_or_cidr="$1"
  local ip="$ip_or_cidr"

  # Se vier CIDR, consideramos o IP base como representativo.
  # (Regra simples para começar. Se quiser interseção de blocos, adaptamos.)
  if [[ "$ip_or_cidr" == */* ]]; then
    ip="${ip_or_cidr%%/*}"
  fi

  # Se desativada ou arquivo não configurado/presente → não bloqueia
  if [[ "${WHITELIST_ENABLED:-0}" != "1" || -z "${WHITELIST_JSON:-}" || ! -f "${WHITELIST_JSON}" ]]; then
    echo ""
    return 0
  fi

  # Se jq não existe → não aplica whitelist (evita quebrar execução)
  if ! command -v jq >/dev/null 2>&1; then
    echo ""
    return 0
  fi

  # Valida o JSON (evita quebrar com set -euo pipefail)
  if ! jq -e . "${WHITELIST_JSON}" >/dev/null 2>&1; then
    # JSON inválido → ignore whitelist
    echo ""
    return 0
  fi

  # Pega total de entradas (pode ser 0)
  local count; count="$(jq -r '.ipv4 | length // 0' "${WHITELIST_JSON}")"
  if [[ -z "$count" || "$count" == "null" || "$count" -eq 0 ]]; then
    echo ""
    return 0
  fi

  local i=0
  while (( i < count )); do
    # Lê par cidr/nota (pode vir null)
    local cidr note
    cidr="$(jq -r ".ipv4[$i].cidr" "${WHITELIST_JSON}")"
    note="$(jq -r ".ipv4[$i].nota" "${WHITELIST_JSON}")"

    # Ignora entradas vazias/nulas
    if [[ -n "$cidr" && "$cidr" != "null" ]]; then
      # Se veio IP puro sem '/', normaliza para /32
      if [[ "$cidr" != */* ]]; then
        cidr="${cidr}/32"
      fi

      # Match?
      if ip_in_cidr "$ip" "$cidr"; then
        # Retorna a nota (pode ser "null" → normalizamos para string vazia)
        if [[ -n "$note" && "$note" != "null" ]]; then
          echo "$note"
        else
          echo ""
        fi
        return 0
      fi
    fi

    i=$(( i + 1 ))
  done

  # Sem match
  echo ""
  return 0
}
