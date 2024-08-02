#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function install_deps () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local DME_PATH="$(readlink -m -- "$BASH_SOURCE"/../..)"
  cd -- "$DME_PATH" || return $?

  local PKG=(
    liblockfile-simple-perl
    libstring-shellquote-perl
    libwww-perl   # LWP::UserAgent
  )
  sudo apt-get install "${PKG[@]}" || return $?
}










[ "$1" == --lib ] && return 0; install_deps "$@"; exit $?
