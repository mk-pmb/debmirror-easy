#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function clear_repo_urls () { REPO_URL=(); }


function dump_rc () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  local DME_PATH="$(dirname -- "$SELFPATH")"

  source -- "$SELFPATH"/lib_rc_util.sh --lib || return $?

  local TOPIC="$1"; shift
  local RC="$1"; shift
  case "$RC" in
    '' ) echo "E: no rc filename given" >&2; return 3;;
    --example )
      RC="$DME_PATH"/docs/example.dm-easy.rc
      function clear_repo_urls () { true; }
      ;;
  esac

  local -A REPO_URL=()
  local CFG_DIR="$(dirname -- "$RC")"
  cd -- "$CFG_DIR" || return $?
  local -A REPO_URL=() REPO_CFG=()
  source -- "$(basename -- "$RC")" || return $?
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


function dump_rc__shq () {
  source -- "$SELFPATH"/shq.sh --lib || return $?
  local KEY= VAL=
  for KEY in "$@"; do
    case "$KEY" in
      '@'* ) shq_list "${KEY:1}";;
      '%'* ) shq_dict_add_sort "${KEY:1}";;
      * ) eval 'VAL="$'"$KEY"'"'; echo -n "$KEY="; shq "$VAL"; echo;;
    esac
  done
}


















dump_rc "$@"; exit $?
