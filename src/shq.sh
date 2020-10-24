#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
#
# shq: shell quoting lib


function shq () {
  # basically printf '%q' but with nicer quotes for items with trailing space.
  if [ -z "$1" ]; then
    true # echo -n "''"
  elif [[ "$1" == *[^A-Za-z0-9/=_\.+\-]* ]]; then
    local VAL="$1" APOS="'" QUOT='"' BSL="\\" USD='$'
    VAL="${VAL//$APOS/$APOS$BSL$APOS$APOS}"
    VAL="'$VAL'"
    VAL="${VAL#"''"}"
    VAL="${VAL%"''"}"
    echo -n "$VAL"
  else
    echo -n "$1"
  fi
}


function shq_list () {
  eval 'local LIST=( "${'"${1%'+'}"'[@]}" )'
  echo -n "$1=("
  [ "${#LIST[@]}" == 0 ] || echo -n ' '
  local ITEM=
  for ITEM in "${LIST[@]}"; do
    if [ -n "$ITEM" ]; then
      shq "$ITEM"
    else
      echo -n "''"
    fi
    echo -n ' '
  done
  echo ')'
}


function shq_dict_add_sort () {
  eval 'local KEYS=( "${!'"$1"'[@]}" )'
  [ "${#KEYS[@]}" -ge 2 ] || [ -n "${KEYS[0]}" ] || return 0
  readarray -t KEYS < <(printf '%s\n' "${KEYS[@]}" | sort -${SHQ_SORT_OPT:-V})
  local DICT="$1" KEY= VAL=
  for KEY in "${KEYS[@]}"; do
    eval 'VAL="${'"$DICT"'[$KEY]}"'
    echo -n "$DICT["
    shq "$KEY"
    echo -n "]="
    shq "$VAL"
    echo
  done
}















[ "$1" == --lib ] && return 0; "$@"; exit $?
