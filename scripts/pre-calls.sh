#!/usr/bin/env bash
if [[ -z "${1}" ]]; then
  echo "Nenhum argumento passado"
else
  set -Eeuo pipefail

  echo "Executando scripts $1"

  for hook in ./scripts/$1/*; do
    echo -e "\e[32mExecutando: $hook \e[0m"; "$hook" "$@";
  done
fi

