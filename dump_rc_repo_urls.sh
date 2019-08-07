#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function dump_rc_repo_urls () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local RC="$1"; shift
  case "$RC" in
    --ignore-clear )
      function clear_repo_urls () { true; }
      RC="$1"; shift
      ;;
  esac
  local -A REPO_URL=()
  source -- "$RC" || return $?
  local KEY= URL=
  for KEY in "${!REPO_URL[@]}"; do
    URL="${REPO_URL[$KEY]}"
    URL="${URL//[$'\r\n \t']/}"
    echo "$KEY $URL"
  done | LANG=C sort -V
}


dump_rc_repo_urls "$@"; exit $?
