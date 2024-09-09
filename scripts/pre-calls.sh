#!/usr/bin/env bash
if [[ -z "${1}" ]]; then
  echo "Nenhum argumento passado"
else
  set -Eeuo pipefail

  echo "Executando scripts $1"

  for hook in $(find ./scripts/$1 -maxdepth 1 -type f -name *.sh); do
    echo -e "\e[32mExecutando: $hook \e[0m"; "$hook" "$@";
  done
fi

