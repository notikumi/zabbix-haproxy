#!/bin/bash
set -e -o pipefail

if [[ "$1" = */ ]]
then
  HAPROXY_SOCKET="$1"
  shift 1
fi

DEBUG=${DEBUG:-0}
HAPROXY_SOCKET="${HAPROXY_SOCKET:-/var/run/haproxy/info.sock}"
CACHE_FILEPATH="/var/tmp/haproxy_stats.cache"
CACHE_EXPIRATION="5" # in minutes

debug() {
  [ "${DEBUG}" -eq 1 ] && echo "$@" >&2
}

get_stats() {
  find $CACHE_FILEPATH -mmin +${CACHE_EXPIRATION} -delete >/dev/null 2>&1
  if [ ! -e $CACHE_FILEPATH ]
  then
    debug "no cache file found, querying haproxy"
    echo "show stat" | socat ${HAPROXY_SOCKET} stdio > ${CACHE_FILEPATH:-/tmp/.haproxycache}
  else
    debug "cache file found, results are at most ${CACHE_EXPIRATION} minutes stale.."
  fi
}

get() {
  # $1: pattern
  # $2: field
  # $3: return $3 if $_res is empty string, default to 0
  local _res
  _res="$(grep "$1" $CACHE_FILEPATH | cut -d, -f$2)"
  if [ -n "$3" ] || [[ "$3" == "@" ]]
  then
    echo "${_res}"
  else
    echo "${3:-0}"  
  fi
}

ctime() {
  get "^https-frontend,FRONTEND" 2
}
rtime() {
  get "^https-frontend,FRONTEND" 61
}

bin() {
  get "^https-frontend,FRONTEND" 9 9999999999
}

status() {
  local _end="$1"
  local _item="$2"
  get "^${_end},${_item}" 18 @ | cut -d\  -f1
}

if type $1 >/dev/null 2>&1
then
  get_stats && $1 $2 $3 $4
fi
