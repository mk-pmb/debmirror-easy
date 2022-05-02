#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function retry_doubt () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  cd -- "$SELFPATH" || return $?

  local CFG="$1"; shift
  [[ "$CFG" == *.rc ]] || return 4$(
    echo "E: config file name (*.rc) required as first arg" >&2)

  local ITEM=
  for ITEM in Archive-Update-in-Progress-* dists .temp; do
    [ -e "$ITEM" ] || continue
    chmod u+w -- "$ITEM"
    rm --verbose --recursive --one-file-system -- "$ITEM"
  done

  local LOG='logs/dm-easy.crnt.log'
  rm -- "$LOG"
  ( tail --bytes=1M --follow=name --retry --pid=$$ -- "$LOG"
    # echo "D: tail quit."
  ) &
  disown $!
  sleep 0.5s

  echo "D: now running DME."
  ../../debmirror-easy.sh one-config "$CFG" || return $?
}










retry_doubt "$@"; exit $?
