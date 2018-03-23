#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gen_configs () {
  local REPOS=( '
    go-git-service      deb.packager.io/gh/pkgr/gogs/
    phusion-passenger   oss-binaries.phusionpassenger.com/apt/passenger/
    nodejs-v06          deb.nodesource.com/node_6.x/
    nodejs-v08          deb.nodesource.com/node_8.x/
    nodejs-v10          deb.nodesource.com/node_10.x/
    winehq              dl.winehq.org/wine-builds/ubuntu/
    ' )
  [ -n "$WWW_DIR" ] || WWW_DIR='www-pub'

  readarray -t REPOS < <(<<<"${REPOS[0]}" sed -re 's~^\s+~~;s~\s+$~~;/^$/d
    /:\/{2}/!s~\s+~&https://~
    s~\s+~ ~')
  local REPO_DIR=
  local REPO_CFG=
  local REPO_URL=
  for REPO_DIR in "${REPOS[@]}"; do
    [ -n "$REPO_DIR" ] || continue
    REPO_URL="${REPO_DIR#* }"
    REPO_DIR="${REPO_DIR%% *}"
    gen_one_config || return $?
  done
  return 0
}


function gen_one_config () {
  # echo "$REPO_DIR <- '$REPO_URL'"
  mkdir -p "$REPO_DIR" || return $?
  local REPO_CFG="$REPO_DIR/dm-easy.rc"
  local CFG_LN=(
    '# -*- coding: utf-8, tab-width: 2; syntax: bash -*-'
    "REPO_URL[.]='$REPO_URL'"
    'source -- ../defaults.rc || return $?'
    )
  echo -n "$REPO_CFG"$'\t'
  printf '%s\n' "${CFG_LN[@]}" | tee -- "$REPO_CFG" \
    | grep -nFe :// || return 3$(echo 'E: no URL' >&2)
  gen_www_symlinks || return $?
  return 0
}


function gen_www_symlinks () {
  [ -d "$WWW_DIR" ] || return 0
  local WWW_UP="${REPO_DIR%/}"
  WWW_UP="${WWW_UP//[^\/]/}//"
  WWW_UP="${WWW_UP//\//..\/}$REPO_DIR"
  local LINKS=(
    dists
    pool
    log.latest.txt=logs/dm-easy.crnt.log
    log.previous.txt=logs/dm-easy.prev.log
    )
  local WWW_SUB="$WWW_DIR/$REPO_DIR"
  mkdir -p "$WWW_SUB"
  local LINK_NAME=
  local LINK_DEST=
  for LINK_NAME in "${LINKS[@]}"; do
    LINK_DEST="$WWW_UP/${LINK_NAME#*=}"
    LINK_NAME="$WWW_SUB/${LINK_NAME%%=*}"
    [ -L "$LINK_NAME" ] && rm -- "$LINK_NAME"
    ln --symbolic --no-target-directory -- "$LINK_DEST" "$LINK_NAME"
    case "$LINK_NAME" in
      */log.latest.txt )
        LANG=C ls --color=always -l "$LINK_NAME" | sed -re '
          s~^[^\x1B]*(\x1B)~\1~;s~^~\t~';;
    esac
  done
  return 0
}










gen_configs "$@"; exit $?
