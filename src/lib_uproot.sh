#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function drop_privileges () {
  local RUN_AS="$(whoami)"
  [ "$RUN_AS" == root ] || return 0
  echo "W: Running as $RUN_AS! Trying to drop privileges:"
  RUN_AS="$(guess_sane_owner_and_group)"
  [ -n "$RUN_AS" ] || return 4
  echo "D: Will try to re-exec with sudo as $RUN_AS, args: $*"
  local SUDO_CMD=(
    sudo
    --non-interactive
    --preserve-env
    --user "${RUN_AS%:*}" --group "${RUN_AS#*:}"
    -- "$SELFFILE" "$@"
    )
  cd / || return $?   # sudo might be unable to cd $PWD (e.g. fuse.sshfs)
  [ "${DEBUGLEVEL:-0}" -ge 2 ] && echo "D: sudo cmd: ${SUDO_CMD[*]}"
  exec "${SUDO_CMD[@]}"
  return $?
}


function guess_sane_owner_and_group () {
  local RUN_AS="$(stat -c %U:%G "$SELFFILE" | tr -s '\n\r\t ' :)"
  RUN_AS="${RUN_AS%:}"
  if [ "${RUN_AS%:*}" == root ]; then
    echo "E: chown webuser:webgroup '${SELFFILE:-E_NOTSET_SELFFILE}'" >&2
    return 4
  fi
  <<<"$RUN_AS" grep -xPe '[a-z][a-z0-9_\-]*:[a-z][a-z0-9_\-]*' && return 0
  echo "E: Unable to detect appropriate user/group." \
    "If '$RUN_AS' is a valid user:group, its name is too fancy." >&2
  return 7
}


function try_autofix_chown () {
  local CHOWN_CMD=(
    chown
    --changes
    --recursive
    --no-dereference
    )
  [ -f .htaccess ] && "${CHOWN_CMD[@]}" --reference .htaccess -- "$SELFFILE"

  local RUN_AS="$(guess_sane_owner_and_group)"
  [ -n "$RUN_AS" ] || return 4
  CHOWN_CMD+=(
    "$RUN_AS"
    -- {.,}*[^.]*
    )
  echo "I: ${CHOWN_CMD[*]}"
  local CHOWN_RV=
  "${CHOWN_CMD[@]}"
  CHOWN_RV=$?
  echo "I: chown rv=$CHOWN_RV"
  return "$CHOWN_RV"
}










[ "$1" == --lib ] && return 0; exit 3
