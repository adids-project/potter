#!/bin/sh

set -eu

TARGET_PORT=${POTTER_PULL_SSHD_PORT:-443}
COWRIE_PUBLIC_PORT=${COWRIE_PUBLIC_PORT:-22}
CONFIG_FILE=${POTTER_PULL_SSHD_CONFIG_FILE:-/etc/ssh/sshd_config.d/99-potter-pull-port.conf}
SSH_SERVICE=${POTTER_PULL_SSHD_SERVICE:-ssh}
ALLOW_UFW=${POTTER_ALLOW_UFW:-1}
MANAGE_SSHD=${POTTER_MANAGE_SSHD:-1}

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

ensure_root() {
    case "$MANAGE_SSHD" in
        0|false|FALSE|False)
            echo "ensure-sshd-pull-port: POTTER_MANAGE_SSHD=$MANAGE_SSHD のためスキップします"
            exit 0
            ;;
    esac
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi
    if command -v sudo >/dev/null 2>&1; then
        exec sudo env \
            POTTER_PULL_SSHD_PORT="$TARGET_PORT" \
            COWRIE_PUBLIC_PORT="$COWRIE_PUBLIC_PORT" \
            POTTER_PULL_SSHD_CONFIG_FILE="$CONFIG_FILE" \
            POTTER_PULL_SSHD_SERVICE="$SSH_SERVICE" \
            POTTER_ALLOW_UFW="$ALLOW_UFW" \
            POTTER_MANAGE_SSHD="$MANAGE_SSHD" \
            /bin/sh "$0"
    fi
    echo "ensure-sshd-pull-port: root 権限または sudo が必要です" >&2
    exit 1
}

build_config() {
    if [ "$TARGET_PORT" = "$COWRIE_PUBLIC_PORT" ]; then
        echo "ensure-sshd-pull-port: POTTER_PULL_SSHD_PORT と COWRIE_PUBLIC_PORT が競合しています ($TARGET_PORT)" >&2
        exit 1
    fi
    if [ "$TARGET_PORT" = "22" ]; then
        printf '%s\n' \
            '# Managed by potter/scripts/ensure_sshd_pull_port.sh' \
            'Port 22'
        return 0
    fi
    if [ "$COWRIE_PUBLIC_PORT" = "22" ]; then
        printf '%s\n' \
            '# Managed by potter/scripts/ensure_sshd_pull_port.sh' \
            "Port $TARGET_PORT"
        return 0
    fi
    printf '%s\n' \
        '# Managed by potter/scripts/ensure_sshd_pull_port.sh' \
        'Port 22' \
        "Port $TARGET_PORT"
}

ensure_root

if ! is_uint "$TARGET_PORT"; then
    echo "ensure-sshd-pull-port: POTTER_PULL_SSHD_PORT は符号なし整数で指定してください" >&2
    exit 1
fi

if ! is_uint "$COWRIE_PUBLIC_PORT"; then
    echo "ensure-sshd-pull-port: COWRIE_PUBLIC_PORT は符号なし整数で指定してください" >&2
    exit 1
fi

if [ "$TARGET_PORT" -lt 1 ] || [ "$TARGET_PORT" -gt 65535 ]; then
    echo "ensure-sshd-pull-port: POTTER_PULL_SSHD_PORT は 1 から 65535 の範囲で指定してください" >&2
    exit 1
fi

if [ "$COWRIE_PUBLIC_PORT" -lt 1 ] || [ "$COWRIE_PUBLIC_PORT" -gt 65535 ]; then
    echo "ensure-sshd-pull-port: COWRIE_PUBLIC_PORT は 1 から 65535 の範囲で指定してください" >&2
    exit 1
fi

config_dir=$(dirname "$CONFIG_FILE")
mkdir -p "$config_dir"

tmp_file=$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")
trap 'rm -f "$tmp_file"' EXIT INT TERM
build_config >"$tmp_file"

if [ ! -f "$CONFIG_FILE" ] || ! cmp -s "$tmp_file" "$CONFIG_FILE"; then
    mv "$tmp_file" "$CONFIG_FILE"
else
    rm -f "$tmp_file"
fi

if command -v sshd >/dev/null 2>&1; then
    sshd_bin=$(command -v sshd)
else
    sshd_bin=/usr/sbin/sshd
fi

"$sshd_bin" -t
systemctl reload "$SSH_SERVICE"

if [ "$ALLOW_UFW" = "1" ] && command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -q '^Status: active'; then
        ufw allow "${TARGET_PORT}/tcp" >/dev/null
    fi
fi

if command -v ss >/dev/null 2>&1; then
    if ! ss -ltn | grep -Eq "[:.]${TARGET_PORT}[[:space:]]"; then
        echo "ensure-sshd-pull-port: sshd が port $TARGET_PORT で待受を開始していません" >&2
        exit 1
    fi
fi

if [ "$TARGET_PORT" = "22" ]; then
    echo "ensure-sshd-pull-port: sshd を port 22 で待受する設定にしました"
elif [ "$COWRIE_PUBLIC_PORT" = "22" ]; then
    echo "ensure-sshd-pull-port: Cowrie を公開 port 22 に置き、sshd を管理用 port $TARGET_PORT に設定しました"
else
    echo "ensure-sshd-pull-port: sshd を port 22 と port $TARGET_PORT で待受する設定にしました"
fi
