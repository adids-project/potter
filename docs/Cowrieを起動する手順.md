# Cowrieを起動する手順

## 目的

この手順は、推奨のセンサ構成として Cowrie と Zeek live sidecar を起動し、Cowrie の JSON ログを repo 管理下の path に出せることを確認するためのものである。

Cowrie ログを ELK に投入する手順は [ELKでデータを可視化する手順.md](./ELKでデータを可視化する手順.md) を参照。
Cowrie 宛通信を Zeek で live 監視する手順は [Cowrie宛通信をZeekで監視する手順.md](./Cowrie宛通信をZeekで監視する手順.md) を参照。

## 前提

- Docker / Docker Compose が使えること
- この host が公開 sensor host であること
- `make up` を実行できること

## 1. センサ構成を起動する

```bash
make sensor-host-init
make up
```

このコマンドは次を行う。

- `make sensor-host-init`
  - `.potter-sensor-host` marker を作る
  - この host が公開センサホストであることを明示する
- `make up`
  - marker があることを確認する
  - `sshd` を管理用 port `443/tcp` に寄せる
  - `Cowrie` と `Zeek live sidecar` を起動する

その後、[docker-compose.yml](/home/mnl/adids/potter/docker-compose.yml:1) を使って、独立した `potter` project として次を起動する。

- `cowrie`
- `zeek-cowrie-live`

## 2. 起動状態を確認する

```bash
make ps
```

起動に成功すると、少なくとも `cowrie` service が `Up` になる。

## 3. 待受ポート

公開 VPS 用の既定構成では、Cowrie は host の 22/tcp に公開され、管理用 SSH は `443/tcp` 側へ寄せる。

```text
0.0.0.0:22->2222/tcp
```

## 4. ログ保存先

この構成で canonical に確認するログは次である。

```text
cowrie/var/log/cowrie/cowrie.json
```

`cowrie.log` は将来 config を追加した場合の候補ではあるが、現在の Docker 既定構成では常に生成される前提にしない。

補助データや鍵関連は次に出る。

```text
cowrie/var/lib/cowrie/
```

現時点で動作確認済みなのは host key 群と `uuid` の生成までである。

## 5. 最小確認

別 terminal から 22/tcp に接続を試みる。

例:

```bash
nc 127.0.0.1 22
```

接続後、1 行だけ SSH client banner を送る。

```text
SSH-2.0-test-client
```

このあと、`cowrie.json` に少なくとも次の event が出ることを確認する。

- `cowrie.session.connect`
- `cowrie.client.version`
- `cowrie.session.closed`

Docker bridge 越しに接続するため、`src_ip` は `127.0.0.1` ではなく `172.x.x.x` の container bridge address として見える。

## 6. 停止する

```bash
make down
```

## 想定トラブル

### container が起動しない

- `make ps` で status を確認する
- Docker daemon へ接続できるか確認する

### `cowrie.json` が作られない

- `make ps` で container が `Up` か確認する
- 公開した host port に実際に接続したか確認する
- `cowrie/var/log/cowrie/` が container から書き込めるか確認する
- 必要なら `docker compose -p adids-honeypots -f docker-compose.yml logs cowrie` で container stdout/stderr を確認する

### port 22 が使えない

- 既存 process が 22 を使っていないか確認する
- この host が本当に公開センサホストか確認する
- `make sensor-host-init` を実行済みか確認する
- 必要なら `docker-compose.yml` 側の host port を変更する

## 参考

- Cowrie Docker Quick Start: https://docs.cowrie.org/en/stable/docker/README.html
- Cowrie の files of interest と JSON log path: https://docs.cowrie.org/en/stable/README.html
