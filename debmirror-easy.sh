#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function debmirror_easy () {
  export LANG{,UAGE}=en_US.UTF-8
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local DME_FILE="$SELFFILE"
  local DME_PATH="$(dirname -- "$SELFFILE")"
  local DBGLV="${DEBUGLEVEL:-0}"
  local LOG_SUFFIX_E=

  source -- "$DME_PATH"/src/lib_uproot.sh --lib || return $?
  source -- "$DME_PATH"/src/lib_rc_util.sh --lib || return $?
  drop_privileges chdir-to "$PWD" "$@" || return $?

  local DM_PROG=( debmirror )
  local LNBUF_CMD=()
  LANG=C stdbuf --help 2>&1 | grep -m 1 -qPie '\bline[ -]?buffered\b' \
    && LNBUF_CMD=( stdbuf --{output,error}=L )

  dme_cli_run "$@"
  return $?
}


function dme_cli_run () {
  local ACTION=
  while [ "$#" -ge 1 ]; do
    ACTION="$1"; shift
    case "$ACTION" in
      mute ) exec &>/dev/null;;
      chdir-to )
        cd -- "$1" || return $?
        shift;;
      chdir-self )
        cd -- "$DME_PATH" || return $?;;
      one-config )
        mirror_one_config "$@"
        return $?;;
      subdirs-fork-wait )
        forall_subdir_configs mirror_one_config
        return $?;;
      subdirs-setsid )
        forall_subdir_configs setsid_self one-config
        return $?;;
      eval )
        ACTION="$1"; shift
        eval "$ACTION" || return $?;;
      * ) echo "E: $0: unsupported action: ${ACTION:-(none)}" >&2; return 2;;
    esac
  done
}


function fail2 () {
  echo "E: failed to $*" >&2
}


function forall_subdir_configs () {
  local CFG_FN=
  local CFG_NUM=0
  LOG_FN=/dev/logfmt CFG_NAME=$'\r' \
    log_msg I "launching subdir configs: " | tr -d '\n'
  for CFG_FN in [A-Za-z0-9]*/dm-easy.rc; do
    [ -f "$CFG_FN" ] || continue
    let CFG_NUM="$CFG_NUM+1"
    echo -n "${CFG_FN%/*}… "
    "$@" "$CFG_FN" &
  done
  echo "($CFG_NUM)"
  local CFG_RV=
  local MAX_ERR=0
  while true; do
    wait -n; CFG_RV=$?
    [ "$CFG_RV" == 127 ] && break   # no more background jobs
    [ "$CFG_RV" -gt "$MAX_ERR" ] && MAX_ERR="$CFG_RV"
  done
  LOG_FN=/dev/null CFG_NAME=$'\r' log_max_err launch; return $?
}


function log_max_err () {
  local ACTION="$*"
  if [ "$MAX_ERR" == 0 ]; then
    log_msg I "$ACTION done: success"
    return 0
  fi
  log_msg E "$ACTION done: max error code = $MAX_ERR"
  return "$MAX_ERR"
}


function setsid_self () {
  </dev/null setsid "$SELFFILE" mute "$@" &
  disown $!
  sleep 2   # let early output pass before your shell writes its prompt
}


function mirror_one_config () {
  local CFG_FN="$1"
  if [ -d "$CFG_FN" ] || [[ "$CFG_FN" == */ ]]; then
    CFG_FN="${CFG_FN%/}/dm-easy.rc"
  fi
  [ -f "$CFG_FN" ] || return $?$(echo "E: no such config: $CFG_FN" >&2)
  local CFG_DIR="$(dirname -- "$CFG_FN")"
  cd -- "$CFG_DIR" || return $?$(fail2 "chdir to config: $CFG_FN")
  cd -- "$PWD" || return $?$(fail2 "re-chdir to config: $PWD ($CFG_FN)")
  # ^-- make sure we can reach it from /
  CFG_DIR="$PWD"
  local CFG_BFN="$(basename -- "$CFG_FN")"
  local CFG_NAME="$CFG_DIR"
  case "$CFG_NAME" in
    "$HOME" | "$HOME"/* ) CFG_NAME="~${CFG_NAME#$HOME}";;
  esac
  local LOG_TS="$(date +%Y-%m%d-%H%M%S)"
  local LOGS_DIR="$CFG_DIR/logs/"
  local LOG_SUBDIR="${LOG_TS:0:4}/"
  local LOG_BFN="dm-easy.$LOG_TS.$$.log"
  mkdir --parents -- "$LOGS_DIR$LOG_SUBDIR" || return $?
  local LOG_FN="$LOGS_DIR$LOG_SUBDIR$LOG_BFN"
  log_msg D "pid $$ @ $(hostname --fqdn), config file: $CFG_FN" || return $?
  rotate_log_symlinks

  local DISTS=()
  local COMPONENTS=()
  local I18N_LANGS=()
  local ARCHS=()
  local EXTRA_DM_OPTS=()
  local -A REPO_URL=()
  local GNUPGHOME=

  local COPROC=()  # child_stdout child_stdin (no stderr)
  local COPROC_PID=
  coproc log_msg --stdin W config:
  local CFG_RV=
  local LOG_RV=
  source_in_func ./"$CFG_BFN" --dm-easy-rc >&"${COPROC[1]}" 2>&1
  CFG_RV=$?
  exec {COPROC[1]}<&-   # close coproc child's stdin
  wait
  if [ "$CFG_RV" != 0 ]; then
    log_msg E "config returned error code $CFG_RV"
    return "$CFG_RV"
  fi

  local REPO_DIR=
  local SRC_URL=
  local REPO_ERR=
  local MAX_ERR=0
  for REPO_DIR in "${!REPO_URL[@]}"; do
    SRC_URL="${REPO_URL[$REPO_DIR]}"
    SRC_URL="${SRC_URL// /}"
    SRC_URL="${SRC_URL//$'\n'/}"
    mirror_one_repo
    REPO_ERR=$?
    [ "$REPO_ERR" -gt "$MAX_ERR" ] && MAX_ERR="$REPO_ERR"
  done
  [ -n "$REPO_ERR" ] || log_msg W 'no repos defined'

  log_max_err "$FUNCNAME"; return $?
}


function rotate_log_symlinks () {
  local VERBO=
  [ "$DBGLV" -ge 2 ] && VERBO=--verbose
  local LOG_PREV='dm-easy.prev.log'
  [ -L "$LOGS_DIR$LOG_PREV" ] && rm $VERBO -- "$LOGS_DIR$LOG_PREV"
  local LOG_CRNT="${LOGS_DIR}dm-easy.crnt.log"
  [ -f "$LOG_CRNT" ] && mv $VERBO --no-clobber --no-target-directory \
    -- "$LOG_CRNT" "$LOGS_DIR$LOG_PREV"
  # if it's a symlink and mv was unable to rename it, delete it:
  [ -L "$LOG_CRNT" ] && rm $VERBO -- "$LOG_CRNT"
  ln $VERBO --symbolic --no-target-directory \
    -- "$LOG_SUBDIR$LOG_BFN" "$LOG_CRNT"
}


function clear_repo_urls () { REPO_URL=(); }


function log_msg () {
  local LVL="$1"; shift
  local MSG=
  if [ "$LVL" == --stdin ]; then
    while read -d $'\n' -r -s MSG; do
      "$FUNCNAME" "$@" "$MSG" || return $?
    done
    return 0
  fi
  MSG="$(date +'%y%m%d-%H%M%S') $LVL: $*"
  local CFG_NAME_HINT=
  [ "$CFG_NAME" == $'\r' ] || CFG_NAME_HINT=" [@${CFG_NAME:-E_NO_CONFIG}]"
  case "$LVL" in
    E ) MSG+="$LOG_SUFFIX_E";;
  esac
  case "$LVL" in
    D | P ) ;;
    I | H ) echo "$MSG$CFG_NAME_HINT";;
    * ) echo "$MSG$CFG_NAME_HINT" >&2;;
  esac
  case "$LOG_FN" in
    /dev/logfmt | /dev/null ) return 0;;
  esac
  MSG="${MSG//$PWD/.}"
  echo "$MSG" >>"$LOG_FN"; return $?
}


function vfail () {
  "$@" || return $?$(log_msg E "vfail: $* -> rv=$?")
}


function source_in_func () {
  source -- "$@"; return $?
}


function mirror_one_repo () {
  local LOG_SUFFIX_E=" @ dir '$REPO_DIR'"
  log_msg P "start mirror: $REPO_DIR <- $SRC_URL"
  if [ -z "${DM_PROG[*]}" ]; then
    log_msg E 'no DM_PROG'
    return 4
  fi

  local ORIG_URL="$SRC_URL"
  SRC_URL="$("$DME_PATH"/src/expand_repo_url.sed <<<"$SRC_URL")"
  [ -n "$SRC_URL" ] || SRC_URL="$ORIG_URL"
  [ "$SRC_URL" == "$ORIG_URL" ] || log_msg P "repo URL expanded to $SRC_URL"

  local URL_RGX='^([a-z]+)://([a-z0-9.-]+)(/\S*$)'
  [[ "$SRC_URL" =~ $URL_RGX ]] || return 4$(
    log_msg E "unsupported source URL syntax: $SRC_URL")
  local SRC_PROTO="${BASH_REMATCH[1]}"
  local SRC_HOST="${BASH_REMATCH[2]}"
  local SRC_PATH="${BASH_REMATCH[3]}"

  local I18N_RGX="$(printf '%s\n' en "${I18N_LANGS[@]}" \
    | grep -xPe '[a-zA-Z_\-]+' | LANG=C sort --unique)"
  I18N_RGX="${I18N_RGX//$'\n'/|}"
  local DM_ARGS=(
    --verbose     # show progress between downloads.
    )
  [ "$DBGLV" -ge 4 ] && DM_ARGS+=( --debug )

  [ "$SRC_PATH" == / ] || SRC_PATH="${SRC_PATH%/}"
  DM_ARGS+=(
    --method="$SRC_PROTO" --host="$SRC_HOST" --root="$SRC_PATH"
    --passive
    --omit-suite-symlinks
    --rsync-extra=none
    --i18n --exclude='/Translation-(?!('"$I18N_RGX"')\b)\S*\.bz2$'
    # --checksums     # verify local file contents on each update check
    --ignore-missing-release
    --ignore-release-gpg
    --ignore-small-errors
    --disable-ssl-verification
    --state-cache-days=2
    "${EXTRA_DM_OPTS[@]}"
    )

  local DO_NOT_CLEANUP='--ignore'
  DM_ARGS+=(
    $DO_NOT_CLEANUP='^(?!(pool|dists|project|\.temp)/)'
    # make assurance double sure for most important files:
    $DO_NOT_CLEANUP='^logs/'
    $DO_NOT_CLEANUP='^dm-easy\.rc$/'
    )

  [ -n "$GNUPGHOME" ] || local GNUPGHOME='gnupg_home'
  if [ "$GNUPGHOME" == - ]; then
    DM_ARGS+=( --no-check-gpg )
    GNUPGHOME=
  else
    [ "${GNUPGHOME:0:1}" == / ] || GNUPGHOME="$PWD/$GNUPGHOME"
    if [ ! -f "$GNUPGHOME"/trustedkeys.gpg ]; then
      log_msg W "No trustedkeys.gpg in $GNUPGHOME/." \
        "Set GNUPGHOME='-' to disable this warning." \
        "(Use '-/' if that's your directory name.)"
      DM_ARGS+=( --no-check-gpg )
    fi
    GNUPGHOME="$(readlink -m -- "$GNUPGHOME")"
  fi
  export GNUPGHOME

  [ -n "$SRC_USER$SRC_PASS" ] && DM_ARGS+=(
    --user="$SRC_USER" --passwd="$SRC_PASS" )
  [ -n "$SRC_PROXY" ] && DM_ARGS+=( --proxy="${SRC_PROXY#-}" )
  dm_args_id_comma_list --dist= "${DISTS[@]}" || return $?
  dm_args_id_comma_list --arch= "${ARCHS[@]}" || return $?
  dm_args_id_comma_list --section= "${COMPONENTS[@]}" || return $?
  DM_ARGS+=( -- "$REPO_DIR" )

  log_msg D "line-buffer adjustor: $(debug_shell_cmd -1 "${LNBUF_CMD[@]}")"
  log_msg D "debmirror prog: $(debug_shell_cmd -1 "${DM_PROG[@]}")"
  log_msg D "debmirror args: $(debug_shell_cmd -1 "${DM_ARGS[@]}")"
  local DM_RV=skipped
  "${LNBUF_CMD[@]}" "${DM_PROG[@]}" "${DM_ARGS[@]}" \
    2>&1 | log_msg --stdin D dm:
  DM_RV="${PIPESTATUS[0]}"

  sanity_check_dist_dirs

  log_msg P "debmirror retval=$DM_RV"
  return "$DM_RV"
}


function sanity_check_dist_dirs () {
  local DIST= FN=
  local MISS=()
  for DIST in "${DISTS[@]}"; do
    case "$DIST" in
      '' | *' '* | *'#'* ) continue;;
      --exotic=* ) DIST="${DIST#*=}";;
    esac
    FN="$REPO_DIR"/dists/"$DIST"/Release
    [ -f "$FN" ] || MISS+=( "$FN" )
  done
  [ -z "${MISS[0]}" ] || log_msg W \
    "Missing release files (check the logs for details): ${MISS[*]}"
}


function dm_args_id_comma_list () {
  local LIST_OPT="$1"; shift
  local ARGS=
  local ARG=
  local SRC_OPT=
  for ARG in "$@"; do
    case "$ARG" in
      *' '* | *'#'* ) ;;
      SRC ) SRC_OPT='--source';;
      [a-z]* ) ARGS+="$ARG,";;
      --exotic=* ) ARGS+="${ARG#*=},";;
      * ) echo "E: $FUNCNAME: unsupported item format: '$ARG'" >&2; return 3;;
    esac
  done
  [ -n "$ARGS" ] || return 4$(log_msg E "no values for $OPT")
  [ -n "$SRC_OPT" ] || SRC_OPT='--nosource'
  [ "$LIST_OPT" == '--arch=' ] && DM_ARGS+=( "$SRC_OPT" )
  DM_ARGS+=( "$LIST_OPT${ARGS%,}" )
}


function debug_shell_cmd () {
  case "$1" in
    -- ) shift;;
    --stderr )
      shift
      "$FUNCNAME" "$@" >&2
      return $?;;
    -1 )
      shift
      "$FUNCNAME" "$@" | sed -re '
        : merge_lines
        $!{N;b merge_lines}
        s~\n\s*~ ~g
        '
      return 0;;
  esac
  printf '%s\n' "$@" | sed -re '
    /[^A-Za-z0-9,\/.=-]/s~^([A-Za-z-]+=|)|$~&\x27~g
    1!s~^~  ~'
}












debmirror_easy "$@"; exit $?
