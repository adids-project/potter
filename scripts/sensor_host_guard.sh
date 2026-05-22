#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
MARKER_FILE=${POTTER_SENSOR_HOST_MARKER_FILE:-"$ROOT_DIR/.potter-sensor-host"}
MODE=${1:-check}
COWRIE_PUBLIC_PORT=${COWRIE_PUBLIC_PORT:-22}
POTTER_PULL_SSHD_PORT=${POTTER_PULL_SSHD_PORT:-443}

write_marker() {
    cat >"$MARKER_FILE" <<EOF
# Managed by potter/scripts/sensor_host_guard.sh
role=public-sensor-host
created_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cowrie_public_port=$COWRIE_PUBLIC_PORT
management_ssh_port=$POTTER_PULL_SSHD_PORT
EOF
    chmod 600 "$MARKER_FILE" 2>/dev/null || true
}

case "$MODE" in
    check)
        if [ -f "$MARKER_FILE" ]; then
            printf '%s\n' "sensor-host-check: 承認済みセンサホスト用 marker を確認しました: $MARKER_FILE"
            exit 0
        fi
        printf '%s\n' "sensor-host-check: このホストでは 'make up' を実行しません。"
        printf '%s\n' "sensor-host-check: この repo は承認済みの公開センサホスト専用です。"
        printf '%s\n' "sensor-host-check: 対象ホスト上で一度だけ 'make sensor-host-init' を実行してから、もう一度 'make up' を実行してください。"
        printf '%s\n' "sensor-host-check: ローカル PC では $MARKER_FILE を作成しないでください。"
        exit 1
        ;;
    init)
        if [ -f "$MARKER_FILE" ]; then
            printf '%s\n' "sensor-host-init: marker は既に存在します: $MARKER_FILE"
            printf '%s\n' "sensor-host-init: このホストは既に 'make up' 実行許可済みです。"
            exit 0
        fi
        write_marker
        printf '%s\n' "sensor-host-init: marker を作成しました: $MARKER_FILE"
        printf '%s\n' "sensor-host-init: このホストで 'make up' を実行できるようになりました。"
        printf '%s\n' "sensor-host-init: 承認済みの公開センサホストでのみ使用してください。"
        ;;
    *)
        printf '%s\n' "sensor-host-guard: 未対応のモードです: $MODE" >&2
        exit 1
        ;;
esac
