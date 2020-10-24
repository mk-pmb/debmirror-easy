#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gen_configs () {
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  local SELFNAME="$(basename -- "$SELFFILE")"
  local BANNER="Created using $SELFNAME with WWW_DIR=$WWW_DIR"

  local DF_RC='defaults.rc'
  [ -e "$DF_RC" ] || [ -L "$DF_RC" ] \
    || mksym {,"$SELFPATH"/example.subdir-}"$DF_RC"

  [ -n "$DME_RC" ] || local DME_RC='--example'
  local DUMP_RC="$SELFPATH"/../src/dump_rc.sh
  local REPOS=()
  readarray -t  REPOS < <("$DUMP_RC" repo_urls "$DME_RC")
  local REPO_DIR= REPO_RC= REPO_URL=
  for REPO_DIR in "${REPOS[@]}"; do
    [ -n "$REPO_DIR" ] || continue
    REPO_URL="${REPO_DIR#* }"
    REPO_DIR="${REPO_DIR%% *}"
    gen_one_config || return $?
  done
}


function gen_one_config () {
  # echo "$REPO_DIR <- '$REPO_URL'"
  mkdir --parents -- "$REPO_DIR"/logs || return $?
  # Ensure logs exist, to have immediate positive feedback on the webspace.
  >>"$REPO_DIR"/logs/dm-easy.crnt.log
  >>"$REPO_DIR"/logs/dm-easy.prev.log

  local REPO_RC="$REPO_DIR/dm-easy.rc"
  local CFG_LN=(
    '# -*- coding: utf-8, tab-width: 2, syntax: bash -*-'
    "# $BANNER"
    "REPO_URL[.]='$REPO_URL'"
    'source -- ../defaults.rc || return $?'
    )
  echo -n "$REPO_RC"$'\t'
  printf '%s\n' "${CFG_LN[@]}" | tee -- "$REPO_RC" \
    | grep -nFe :// || return 3$(echo 'E: no URL' >&2)
  gen_www_symlinks || return $?
}


function mksym () {
  [ -L "$1" ] && rm -- "$1"
  ln --symbolic --no-target-directory -- "$2" "$1"
}


function gen_www_symlinks () {
  [ -n "$WWW_DIR" ] || return 0
  [ -d "$WWW_DIR" ] || return 3$(
    echo "E: Your WWW_DIR is not a directory: '$WWW_DIR'" >&2)
  WWW_DIR="${WWW_DIR%/}/"
  local WWW_UP="$WWW_DIR" REPOS_SUB= COMMON_PARENT="$(readlink -m .)"
  WWW_UP="${WWW_UP%/}/"
  while [ "${WWW_UP:0:3}" == ../ ]; do
    WWW_UP="${WWW_UP:3}"
    REPOS_SUB="$(basename -- "$COMMON_PARENT")/"
    COMMON_PARENT="$(dirname -- "$COMMON_PARENT")"
  done
  WWW_UP="${REPO_DIR%/}"
  WWW_UP="${WWW_UP//[^\/]/}//"
  WWW_UP="${WWW_UP//\//..\/}${REPOS_SUB}${REPO_DIR}"

  local ARCHS=() COMPONENTS=() DISTS=()
  local -A REPO_CFG=()
  eval "$("$DUMP_RC" shq "$REPO_RC" @ARCHS @COMPONENTS @DISTS %REPO_CFG)"

  local LINKS=()
  [ -z "${REPO_CFG[www_sym]}" ]
  readarray -t LINKS < <(<<<"${REPO_CFG[www_sym]}" grep -oPe '\S+')
  LINKS+=(
    dists
    pool
    log.latest.txt=logs/dm-easy.crnt.log
    log.previous.txt=logs/dm-easy.prev.log
    "${ARCHS[@]}" all
    )

  local WWW_SUB="${WWW_DIR}${REPO_DIR}"
  mkdir --parents -- "$WWW_SUB"

  [ -z "${REPO_CFG[flatdir]}" ] || gen_www_symlinks__flatdir || return $?
  # local CREATED=( . )
  local LINK_NAME= LINK_DEST=
  for LINK_NAME in "${LINKS[@]}"; do
    LINK_DEST="$WWW_UP/${LINK_NAME#*=}"
    LINK_NAME="$WWW_SUB/${LINK_NAME%%=*}"
    mksym "$LINK_NAME" "$LINK_DEST"
    case "$LINK_NAME" in
      */log.latest.txt )
        LANG=C ls --color=always -l "$LINK_NAME" | sed -re '
          s~^[^\x1B]*(\x1B)~\1~;s~^~\t~';;
    esac
    # CREATED=( "$LINK_NAME" )
  done
  # sudo --non-interactive chown --{no-de,}reference . -- "${CREATED[@]}"
}


function gen_www_symlinks__flatdir () {
  local LINK= DEST="dists/${DISTS[0]}"
  for LINK in Release{,.gpg}; do
    mksym "$WWW_SUB/$LINK" "$DEST/$LINK"
  done
  DEST+="/${COMPONENTS[0]}/binary-${ARCHS[0]}"
  for LINK in Packages{,.gz}; do
    mksym "$WWW_SUB/$LINK" "$DEST/$LINK"
  done
}










gen_configs "$@"; exit $?
