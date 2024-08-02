#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function reex () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local DME_PATH="$(readlink -m -- "$BASH_SOURCE"/../..)"
  DME_PATH="$DME_PATH" sh -c '
    cd -- "$DME_PATH" &&
    git fetch origin &&
    git reset --hard origin/experimental &&
    chown --reference . -R .
    ' || return $?
  if [ "$1" == --then ]; then
    shift
    "$@" || return $?
  fi
}


function retry_one_config () {
  local CFG="$1"; shift
  [ -n "$CFG" ] || return 4$(echo E: 'No config file given' >&2)
  CFG="${CFG%/}"
  for CFG in "$CFG"{/dm-easy.rc,}; do [ -f "$CFG" ] && break; done
  "$DME_PATH"/debmirror-easy.sh one-config "$CFG" && return 0
  local RV=$?
  local LOG="${CFG%/*}"/logs/dm-easy.crnt.log
  # tail --lines=20 -- "$LOG"
  # echo -n "^-- rv=$RV | "; wc --lines -- "$LOG"
  less --tilde -- "$LOG"
}


reex "$@"; exit $?
