#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
LOG_PATH="$ROOT_DIR/data/logs/zeek/live/cowrie/current/conn.log"
MAX_READ_BYTES=${POTTER_PULL_MAX_READ_BYTES:-67108864}

fail() {
    echo "potter-pull-force-command: $1" >&2
    exit 1
}

is_uint() {
    case "$1" in
        ''|*[!0-9]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

if ! is_uint "$MAX_READ_BYTES"; then
    fail "POTTER_PULL_MAX_READ_BYTES must be an unsigned integer"
fi

set -f
IFS=' '
set -- ${SSH_ORIGINAL_COMMAND:-}

command_name=${1:-}
case "$command_name" in
    stat)
        if [ "$#" -ne 1 ]; then
            fail "unexpected arguments for stat"
        fi
        if [ ! -f "$LOG_PATH" ]; then
            printf '%s\n' 'missing'
            exit 0
        fi
        stat -c 'ok %i %s' "$LOG_PATH"
        ;;
    read)
        if [ "$#" -ne 3 ]; then
            fail "usage: read <offset> <length>"
        fi
        offset=$2
        length=$3
        if ! is_uint "$offset"; then
            fail "offset must be an unsigned integer"
        fi
        if ! is_uint "$length"; then
            fail "length must be an unsigned integer"
        fi
        if [ "$length" -gt "$MAX_READ_BYTES" ]; then
            fail "requested length exceeds POTTER_PULL_MAX_READ_BYTES"
        fi
        if [ ! -f "$LOG_PATH" ]; then
            exit 0
        fi
        start_byte=$((offset + 1))
        tail -c "+$start_byte" "$LOG_PATH" | head -c "$length"
        ;;
    *)
        fail "unsupported command"
        ;;
esac
