#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gen_configs () {
  local SELFPATH="$(readlink -m "$BASH_SOURCE"/..)"

  local DUMP_RC=( "$SELFPATH"/../dump_rc_repo_urls.sh )
  if [ -z "$DME_RC" ]; then
    local DME_RC="$SELFPATH"/example.dm-easy.rc
    DUMP_RC+=( --ignore-clear )
  fi
  local REPOS=()
  readarray -t  REPOS < <("${DUMP_RC[@]}" "$DME_RC")
  local REPO_DIR= REPO_CFG= REPO_URL=
  for REPO_DIR in "${REPOS[@]}"; do
    [ -n "$REPO_DIR" ] || continue
    REPO_URL="${REPO_DIR#* }"
    REPO_DIR="${REPO_DIR%% *}"
    gen_one_config || return $?
  done
}


function gen_one_config () {
  # echo "$REPO_DIR <- '$REPO_URL'"
  mkdir --parents -- "$REPO_DIR" || return $?
  local REPO_CFG="$REPO_DIR/dm-easy.rc"
  local CFG_LN=(
    '# -*- coding: utf-8, tab-width: 2, syntax: bash -*-'
    "REPO_URL[.]='$REPO_URL'"
    'source ../defaults.rc || return $?'
    )
  echo -n "$REPO_CFG"$'\t'
  printf '%s\n' "${CFG_LN[@]}" | tee "$REPO_CFG" \
    | grep -nFe :// || return 3$(echo 'E: no URL' >&2)
  gen_www_symlinks || return $?
}


function  gen_www_symlinks () {
  [ -n "$WWW_DIR" ] || return 0
  [ -d "$WWW_DIR" ] || return 3$(
    echo "E: Your WWW_DIR is not a directory: '$WWW_DIR'" >&2)
  local WWW_UP="$WWW_DIR" REPOS_SUB= COMMON_PARENT="$(readlink -m "$PWD")"
  WWW_UP="${WWW_UP%/}/"
  while [ "${WWW_UP:0:3}" == ../ ]; do
    WWW_UP="${WWW_UP:3}"
    REPOS_SUB="$(basename "$COMMON_PARENT")/"
    COMMON_PARENT="$(dirname "$COMMON_PARENT")"
  done
  WWW_UP="${REPO_DIR%/}"
  WWW_UP="${WWW_UP//[^\/]/}//"
  WWW_UP="${WWW_UP//\//..\/}${REPOS_SUB}${REPO_DIR}"
  local LINKS=(
    dists
    pool
    log.latest.txt=logs/dm-easy.crnt.log
    log.previous.txt=logs/dm-easy.prev.log
    )
  local WWW_SUB="${WWW_DIR}${REPO_DIR}"
  mkdir --parents -- "$WWW_SUB"
  local CREATED=( . )
  local LINK_NAME= LINK_DEST=
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
    CREATED=( "$LINK_NAME" )
  done
  # sudo --non-interactive chown --{no-de,}reference . -- "${CREATED[@]}"
}










gen_configs "$@"; exit $?
