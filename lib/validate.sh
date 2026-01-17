#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

is_valid_ip_or_cidr() {
  local input="$1"

  if [[ ! "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?$ ]]; then
    return 1
  fi

  local ip="${input%%/*}"
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"

  for octet in $o1 $o2 $o3 $o4; do
    if (( octet < 0 || octet > 255 )); then
      return 1
    fi
  done

  return 0
}
