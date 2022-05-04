#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function pkgs2json () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  cd -- "$SELFPATH" || return $?

  local FILES=( "$@" )
  [ "$#" == 0 ] && FILES+=( dists/*/*/*/Packages.gz )
  local GZ=
  for GZ in "${FILES[@]}"; do
    one_gz || return $?
  done
}


function one_gz () {
  local BUF="$GZ"; BUF="${BUF#*/}"
  local DIST="${BUF%%/*}"; BUF="${BUF#*/}"
  local COMP="${BUF%%/*}"; BUF="${BUF#*/}"
  local ARCH="${BUF%%/*}"; BUF="${BUF#*/}"
  ARCH="${ARCH#binary-}"
  local SAVE="tmp.pkg.$DIST.$ARCH"
  [ "$COMP" == main ] || SAVE+=".$COMP"
  SAVE+=".json"

  <"$GZ" gzip --decompress | ../../util/debctrl2json.sed >"$SAVE"
  local RV_SUM="${PIPESTATUS[*]}"
  let RV_SUM="${RV_SUM// /+}"

  du --human-readable --apparent-size -- "$SAVE"

  return "$RV_SUM"
}










pkgs2json "$@"; exit $?
