# 公開VPSセンサーノード準備手順

## 目的

この手順は、ConoHa などの公開 VPS 上に Cowrie + Zeek live capture を置き、手元 PC 側で `Cowrie Live Attack Monitoring` を使うための運用方針を固定するためのものである。

この文書で扱うのは次である。

- 公開 VPS 側で Cowrie と Zeek live capture を起動する
- 手元 PC 側で ELK と dashboard を起動する
- `公開VPS` と `手元PC` の 2 台だけを使う前提で、`home PC pull` をどう運用するかを決める

## 1. 先に結論

現在の推奨は、`公開VPS 収集専用 + 手元PC pull + 手元PC local ingest` 構成である。

repo 側で実装済みなのは次である。

- 公開 VPS 上で使える `docker-compose.yml`
- `make up`
- 公開 VPS 側の [potter_pull_force_command.sh](/home/mnl/adids/potter/scripts/potter_pull_force_command.sh:1)
- 手元 PC 側の `make up`
- 手元 PC 側の `make pull-once`

運用で決める必要があるのは次である。

- 公開 VPS の公開 IP / DNS
- `potter_pull` 用の SSH 鍵と権限
- 手元 PC 側 puller の実行間隔
- 公開 VPS 側で `conn.log` を何日保持するか

補足:

- `elk` 側の Filebeat は、ELK マシン上に既にある `conn.log` を読む local ingest である
- `potter` 側の remote shipper は実装として残っているが、`公開VPS が侵害されうる` という前提では推奨しない

## 2. 推奨アーキテクチャ

```text
                Internet attackers
                        |
                        v
+---------------------------------------------------+
| Public VPS / Sensor                               |
|                                                   |
|  Cowrie (2222/tcp)                                |
|      |                                            |
|      v                                            |
|  Zeek live capture                                |
|      |                                            |
|      v                                            |
|  data/logs/zeek/live/cowrie/current/conn.log      |
|                                                   |
|  置かないもの:                                     |
|  - ELK の送り先情報                               |
|  - shipper 認証情報                               |
|  - CA 証明書                                      |
+---------------------------------------------------+
                        ^
                        | SSH pull only
                        | read-only user + key
                        | cron every minute
                        | effective pull every 1m or 5m
                        |
+---------------------------------------------------+
| Home PC                                           |
|                                                   |
|  puller                                           |
|   - interval configurable                         |
|   - inode/offset state                            |
|   - append-only sync                              |
|      |                                            |
|      v                                            |
|  elk/data/logs/zeek/live/cowrie/current/conn.log  |
|      |                                            |
|      v                                            |
|  local Filebeat ingest                            |
|      |                                            |
|      v                                            |
|  Elasticsearch -> Kibana                          |
+---------------------------------------------------+
```

この構成を採る理由は次の通り。

- 公開 VPS に `手元PC の送り先情報` を置かなくて済む
- `Cowrie + Zeek` に責務を絞れるため、公開側の運用が単純になる
- `conn.log` は公開 VPS 側に残るため、手元 PC 復旧後に追いつける

## 3. なぜ push を採らないか

`公開VPS` と `手元PC` の 2 台しか使わず、かつ `公開VPS が侵害される可能性を考える` 場合、次の 2 つは同時に満たせない。

- 公開 VPS に送り先情報や shipper credential を置かない
- 手元 PC が落ちている間も自動転送を継続する

そのため、この構成では `push` を捨てて `pull` を選ぶ。

## 4. 公開VPS 側の前提

推奨:

- Ubuntu 22.04 以上
- Docker / Docker Compose plugin 導入済み
- `potter` repo を clone 済み

必要 port:

- `2222/tcp`
  - Cowrie SSH
- `22/tcp`
  - 管理 SSH

開けないもの:

- `5601/tcp`
- `9200/tcp`
- `5044/tcp`

secret 配置の原則:

- 公開 VPS には ELK 用 `.env` を置かない
- `filebeat/certs/ca/ca.crt` を配らない
- `.env.shipper` を作らない

local ELK 用 secret の扱いは [シークレット管理.md](/home/mnl/adids/elk/docs/シークレット管理.md:1) を参照。

## 5. 公開VPS 側で repo を起動する

公開 VPS 側の repo root:

```bash
make up
make ps
```

期待する service:

- `cowrie`
- `zeek-cowrie-live`

この repo の入口は `make up`, `make down`, `make ps` の 3 つに絞っている。

## 6. 公開VPS 側の確認

Cowrie に対して外から接続試行が来ると、少なくとも次が増える。

```text
data/logs/zeek/live/cowrie/current/conn.log
```

簡単な確認:

```bash
ls -l data/logs/zeek/live/cowrie/current/conn.log
tail -n 5 data/logs/zeek/live/cowrie/current/conn.log
```

## 7. 手元PC 側の起動

手元 PC 側 repo root:

```bash
make up
make ps
```

Kibana で開くもの:

- `Cowrie Live Attack Monitoring`

この構成では、手元 PC 側の Filebeat が `elk/data/logs/zeek/live/cowrie/current/conn.log` を監視し、`zeek-cowrie-live-*` に投入する。
`ELK_STACK_MODE=live` のときは、`make up` が managed cron の登録まで行う。

## 8. 手元PC puller の方針

puller は手元 PC 側だけで動かす。
役割は、公開 VPS の `conn.log` を `append-only` に回収し、手元 PC の `elk` 側監視 path に追記することだけである。

### 8-1. 設定項目

設定の正本は、手元 PC 側 `elk/.env` とする。
最低限、次の設定を持たせる。

```env
ELK_STACK_MODE=live
PULL_INTERVAL_MINUTES=5

PULL_REMOTE_HOST=conoha-sensor
PULL_REMOTE_PORT=22
PULL_REMOTE_USER=potter_pull
PULL_REMOTE_LOG_PATH=/path/to/potter/data/logs/zeek/live/cowrie/current/conn.log
PULL_SSH_KEY_PATH=/home/.../.ssh/potter_pull_ed25519
PULL_KNOWN_HOSTS_PATH=/home/.../.ssh/known_hosts
PULL_MAX_BYTES_PER_RUN=67108864
PULL_SSH_CONNECT_TIMEOUT_SECONDS=15
PULL_SSH_COMMAND_TIMEOUT_SECONDS=120
```

### 8-2. 推奨間隔

- `demo`: `PULL_INTERVAL_MINUTES=1`
- `normal`: `PULL_INTERVAL_MINUTES=5`

この値は手元 PC 側の設定だけで切り替える。
公開 VPS 側の設定は変えない。

実行形態は次を前提にする。

- cron は `毎分` 起動する
- puller 自体が `PULL_INTERVAL_MINUTES` を見て、該当 minute だけ実際に pull する

そのため、`demo -> normal` の切り替えは config 編集だけで済む。

### 8-3. 同期のしかた

puller は次の方針で動かす。

- `SSH` で公開 VPS に接続する
- 公開 VPS 側の `scripts/potter_pull_force_command.sh` を `forced-command` で実行する
- `前回 offset 以降` の追記分だけを読む
- `最後が改行で閉じた完全な JSON 行だけ` を `LOCAL_LOG_PATH` に追記する
- 最終行が途中までしか届いていない場合は、その行ぶんの offset を進めない
- 実行中は `LOCK_PATH` で多重起動を防ぐ

### 8-4. state の最小項目

puller の state は少なくとも次を持つ。

- `remote_inode`
- `remote_offset`
- `updated_at`

`inode` が変わった、または file size が `remote_offset` より小さくなった場合は、remote file が再作成されたものとして `offset=0` から読み直す。

## 9. `potter_pull` ユーザの方針

公開 VPS 側には、手元 PC が pull するための専用ユーザ `potter_pull` を置く。

方針:

- 手元 PC 専用の公開鍵だけを許可する
- `conn.log` のある path を読むための権限だけを与える
- ELK credential や CA 証明書は一切持たせない
- 可能なら port forwarding / agent forwarding / X11 forwarding / PTY を無効化する
- `forced-command` で [potter_pull_force_command.sh](/home/mnl/adids/potter/scripts/potter_pull_force_command.sh:1) だけを実行できるようにする

`authorized_keys` の例:

```text
command="/path/to/potter/scripts/potter_pull_force_command.sh",restrict ssh-ed25519 <PUBLIC_KEY> home-pc-cowrie-pull
```

このスクリプトは、次の 2 操作だけを許可する。

- `stat`
- `read <offset> <length>`

手元 PC 側 puller は、これらを `SSH_ORIGINAL_COMMAND` 経由で使う。

### 9-1. 手元PC 側の初期化

手元 PC 側 `elk` repo root:

```bash
make pull-once
```

`pull-once` は、その場で 1 回だけ pull する。

## 10. 手元PC が落ちたときの扱い

手元 PC が落ちている間は、転送は止まるが収集は止まらない。

- `cowrie`
- `zeek-cowrie-live`
- `conn.log` への追記

は公開 VPS 上で継続する。

一方で、公開 VPS が侵害された場合、`まだ手元 PC に pull していない区間` は改ざん・削除されうる。
この危険窓を小さくするために、`demo=1分`、`normal=5分` を基本とする。

## 11. 発表前チェックリスト

- 公開 VPS で `make ps` が `Up`
- `data/logs/zeek/live/cowrie/current/conn.log` が更新されている
- 手元 PC で `make ps` が `Up`
- puller が `LOCAL_LOG_PATH` に追記できている
- Kibana の `Cowrie Live Attack Monitoring` が開ける
- `zeek-cowrie-live-*` に document がある

## 12. 参考

- Cowrie 宛通信の最小確認: [Cowrie宛通信をZeekで監視する手順.md](/home/mnl/adids/potter/docs/Cowrie宛通信をZeekで監視する手順.md:1)
- ELK 全体構成: [ELK構成とデータフロー.md](/home/mnl/adids/elk/docs/ELK構成とデータフロー.md:1)
- optional な shipper credential の扱い: [シークレット管理.md](/home/mnl/adids/elk/docs/シークレット管理.md:1)
