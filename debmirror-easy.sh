#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function debmirror_easy () {
  export LANG{,UAGE}=en_US.UTF-8
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local DME_FILE="$SELFFILE"
  local DME_PATH="$(dirname -- "$SELFFILE")"
  local DBGLV="${DEBUGLEVEL:-0}"
  local LOG_SUFFIX_E=

  source "$DME_PATH"/src/lib_uproot.sh --lib || return $?
  source "$DME_PATH"/src/lib_rc_util.sh --lib || return $?
  drop_privileges chdir-to "$PWD" "$@" || return $?

  local DM_PROG=( debmirror )
  local LNBUF_CMD=()
  LANG=C stdbuf --help 2>&1 | grep -m 1 -qPie '\bline[ -]?buffered\b' \
    && LNBUF_CMD=( stdbuf --{output,error}=L )
  local LOG_HOST="$(hostname --fqdn)" # <- local config files may optimize it.
  read_early_local_config || return $?

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
  log_msg D "pid $$ @ $LOG_HOST, config file: $CFG_FN" || return $?
  rotate_log_symlinks

  local MAX_ERR=0
  local CFG_RERUN=
  # see doc/reruns.md
  mirror_one_config__rerun || return $?
  for CFG_RERUN in $CFG_RERUN; do
    [ -n "$CFG_RERUN" ] || continue
    log_msg D "config rerun: $CFG_RERUN"
    mirror_one_config__rerun || return $?
  done

  log_max_err "$FUNCNAME"; return $?
}


function mirror_one_config__rerun () {
  local DISTS=()
  local COMPONENTS=()
  local I18N_LANGS=()
  local ARCHS=()
  local EXTRA_DM_OPTS=()
  local -A REPO_URL=()
  local -A REPO_OPT=(
    [rsync_extra]='none'
    [expunge_other_dists]='yes'
    )
  local GNUPGHOME=

  log_redir_subtask W 'config' \
    source_in_func ./"$CFG_BFN" --dm-easy-rc || return $?

  local REPO_DIR=
  local SRC_URL=
  local REPO_ERR=
  for REPO_DIR in "${!REPO_URL[@]}"; do
    SRC_URL="${REPO_URL[$REPO_DIR]}"
    SRC_URL="${SRC_URL// /}"
    SRC_URL="${SRC_URL//$'\n'/}"
    mirror_one_repo
    REPO_ERR=$?
    [ "$REPO_ERR" -gt "$MAX_ERR" ] && MAX_ERR="$REPO_ERR"
  done
  [ -n "$REPO_ERR" ] || log_msg W 'no repos defined'

  mirror_one_config__hook on_config_done D || return $?
}


function mirror_one_config__hook () {
  local HOOK_EVT="$1"; shift
  local LOG_LEVEL="$1"; shift
  local HOOK_CMD="${REPO_OPT[$HOOK_EVT]}"
  case "$HOOK_CMD" in
    '' ) return 0;;
    --* ) HOOK_CMD='source_in_func ./"$CFG_BFN" '"$HOOK_CMD";;
  esac
  log_msg P "run $HOOK_EVT hook: $HOOK_CMD"
  log_redir_subtask "$LOG_LEVEL" "$HOOK_EVT" eval "$HOOK_CMD"
  local HOOK_RV="$?"
  log_msg P "done $HOOK_EVT hook, rv=$HOOK_RV"
  return "$HOOK_RV"
}


function log_redir_subtask () {
  local LOG_LEVEL="$1"; shift
  local TASK_DESCR="$1"; shift
  local COPROC=()  # child_stdout child_stdin (no stderr)
  local COPROC_PID=
  coproc log_msg --stdin "$LOG_LEVEL" "$TASK_DESCR:"
  local TASK_RV=
  "$@" >&"${COPROC[1]}" 2>&1
  TASK_RV=$?
  exec {COPROC[1]}<&-   # close coproc child's stdin
  wait
  [ "$TASK_RV" == 0 ] || log_msg E "$TASK_DESCR returned error code $TASK_RV"
  return "$TASK_RV"
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
    while IFS= read -d $'\n' -r -s MSG; do
      "$FUNCNAME" "$@" "$MSG" || return $?
    done
    return 0
  fi
  printf -v MSG -- '%(%y%m%d-%H%M%S)T %s' -1 "$LVL: $*"
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
  source "$@"; return $?
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

  check_unsupported_repo_opts || return $?

  [ "$SRC_PATH" == / ] || SRC_PATH="${SRC_PATH%/}"
  DM_ARGS+=(
    --method="$SRC_PROTO" --host="$SRC_HOST" --root="$SRC_PATH"
    --passive
    --omit-suite-symlinks
    --rsync-extra="${REPO_OPT[rsync_extra]}"
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
    $DO_NOT_CLEANUP='^[^/]+\.rc$'
    )
  maybe_expunge_other_dists || return $?

  [ -n "$GNUPGHOME" ] || local GNUPGHOME='gnupg_home'
  if [ "$GNUPGHOME" == - ]; then
    DM_ARGS+=( --no-check-gpg )
    GNUPGHOME=
  else
    [ "${GNUPGHOME:0:1}" == / ] || GNUPGHOME="$PWD/$GNUPGHOME"
    if [ ! -f "$GNUPGHOME"/trustedkeys.gpg ]; then
      log_msg W "no trustedkeys.gpg in $GNUPGHOME/." \
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
  log_msg D "DM_EVAL_HTTPGET_MODIFY_URL: $DM_EVAL_HTTPGET_MODIFY_URL"
  local DM_RV=skipped
  "${LNBUF_CMD[@]}" "${DM_PROG[@]}" "${DM_ARGS[@]}" \
    2>&1 | log_msg --stdin D dm:
  DM_RV="${PIPESTATUS[0]}"

  sanity_check_dist_dirs

  log_msg P "debmirror retval=$DM_RV"
  return "$DM_RV"
}


function check_unsupported_repo_opts () {
  local KEY=
  for KEY in "${!REPO_OPT[@]}"; do case "$KEY" in
    expunge_other_dists | \
    on_config_done | \
    rsync_extra | \
    '' ) ;;
    * ) BAD+=( "$KEY" );;
  esac; done
  [ "${#BAD[@]}" == 0 ] && return 0
  log_msg E "unsupported REPO_OPT option(s) (typo?): ${BAD[*]}"
  return 3
}


function maybe_expunge_other_dists () {
  local KEY='expunge_other_dists'
  local VAL="${REPO_OPT[$KEY]}"
  case "$VAL" in
    yes )
      # This is DM's default behavior.
      return 0;;
    no ) ;;
    * )
      log_msg E "option REPO_OPT[$KEY] must be either 'yes' or 'no'."
      return 3;;
  esac

  # Construct regexp for enabled dists:
  local CUR="${DISTS[*]}"
  CUR="${CUR// /,}"
  local ACCEPTABLE_CHARS='A-Za-z0-9_-'
  local ERR=
  case ",$CUR," in
    ,, ) ERR='is empty';;
    *,,* ) ERR='includes an empty item';;
    * )
      ERR="${CUR//[,$ACCEPTABLE_CHARS]/}"
      [ -z "$ERR" ] || ERR="contains unsupported characters: '$ERR'";;
  esac
  if [ -n "$ERR" ]; then
    log_msg E "$FUNCNAME: cannot construct regexp: List of dists $ERR"
    return 3
  fi
  CUR="(?:${CUR//,/|})"

  # Negate that to construct a regexp of all other dists:
  local OTHERS='^(?:\.temp/|)dists/(?!'"$CUR"'/)'
  DM_ARGS+=( --ignore="$OTHERS" )
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

  local NO_PKG="$(tail --lines=5 -- "$LOG_FN" \
    | grep -Fe ' dm: No packages after parsing Packages and Sources files')"
  NO_PKG="${NO_PKG##*: }"
  [ -z "$NO_PKG" ] || MISS+=(
    "(Missing release files are probably due to earlier error: '$NO_PKG')" )

  [ -n "${MISS[0]}" ] || return 0
  log_msg W "$FUNCNAME:" \
    "missing release files (check the logs for details): ${MISS[*]}"
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
  [ -n "$ARGS" ] || return 4$(log_msg E "no values for $LIST_OPT")
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


function read_early_local_config () {
  local CFG_FN=
  for CFG_FN in "$DME_PATH"/local/{cfg/,*.cfg/}; do
    for CFG_FN in "${CFG_FN%/}"/*.rc; do
      [ -f "$CFG_FN" ] || continue
      source_in_func "$CFG_FN" || return $?$(
        echo "Config failed: $CFG_FN: rv=$?" >&2)
    done
  done
}












debmirror_easy "$@"; exit $?
