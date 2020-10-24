#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function clear_repo_urls () { true; }


function dump_rc () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local TOPIC="$1"; shift
  local RC="$1"; shift
  local -A REPO_URL=()
  [ -n "$RC" ] || return 3$(echo "E: no rc filename given" >&2)
  source -- "$RC" || return $?
  "${FUNCNAME}__$TOPIC" "$@" || return $?
}


function dump_rc__repo_urls () {
  local KEY= URL=
  for KEY in "${!REPO_URL[@]}"; do
    URL="${REPO_URL[$KEY]}"
    URL="${URL//[$'\r\n \t']/}"
    echo "$KEY $URL"
  done | LANG=C sort -V
}


dump_rc "$@"; exit $?
