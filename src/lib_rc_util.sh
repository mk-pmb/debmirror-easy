#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function array_sed () {
  local A_NAME="$1"; shift
  local A_LINES=()
  eval 'A_LINES=( "${'"$A_NAME"'[@]}" )'
  readarray -t A_LINES < <(printf '%s\n' "${A_LINES[@]}" | LANG=C sed "$@")
  eval "$A_NAME"'=( "${A_LINES[@]}" )'
}










[ "$1" == --lib ] && return 0; exit 3
