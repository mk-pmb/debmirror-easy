#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function unpriv () {
  export LANG{,UAGE}=en_US.UTF-8
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local DME_PATH="$(dirname -- "$SELFFILE")"

  source -- "$DME_PATH"/src/lib_uproot.sh --lib || return $?

  local RUNMODE="$1"; shift

  case "$RUNMODE" in
    -b | --forkoff )
      </dev/null setsid "$SELFFILE" "$@" &
      disown $!
      sleep 2   # let early output pass before your shell writes its prompt
      return 0;;
    -C | --autofix-chown ) try_autofix_chown; return $?;;
  esac

  drop_privileges "$@" || return $?

  case "$RUNMODE" in
    -g | --unpriv-git ) git "$@"; return $?;;
  esac

  echo "E: unsupported runmode: ${RUNMODE:-(none)}" >&2
  return 2
}






[ "$1" == --lib ] && return 0; unpriv "$@"; exit $?
