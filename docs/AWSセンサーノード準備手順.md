# AWSセンサーノード準備手順

## 目的

この手順は、AWS EC2 上に Cowrie + Zeek live capture を置き、local PC 側の Kibana で `Cowrie Live Attack Monitoring` を使うための準備項目を固定する。

この文書で扱うのは次である。

- EC2 側で Cowrie と Zeek live capture を起動する
- local PC 側で ELK と dashboard を起動する
- どこまでが repo 実装済みで、どこからが運用準備かを分ける

## 1. 先に結論

repo 側で実装済みなのは次である。

- EC2 上で使える `docker-compose.yml`
- `make cowrie-live-up`
- `make cowrie-live-shipper-up`
- local PC 側の `make elk-up-cowrie-live`
- `make kibana-import-cowrie-live-dashboard`

まだ運用で決める必要があるのは次である。

- EC2 の公開 IP / DNS
- Security Group
- local PC から Kibana を見る時間帯と time range
- secret をどのノードに置くか

補足:

- `adids-elk` 側の Filebeat は、ELK マシン上にある `conn.log` を読む local ingest である
- AWS 側で 1 行ごとに送りたい場合は、`adids-honeypots` 側の remote shipper を使う

## 2. EC2 側の前提

推奨:

- Ubuntu 22.04 以上
- Docker / Docker Compose plugin 導入済み
- repo を clone 済み

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

- Cowrie センサ専用 EC2 には、不要な ELK 用 `.env` を置かない
- `docker-compose.yml` だけで足りるなら、`ELASTIC_PASSWORD` や `ENCRYPTION_KEY` は local PC 側だけに置く
- local ELK 用 secret の扱いは [シークレット管理.md](./シークレット管理.md) を参照

## 3. Security Group

最小構成:

```text
allow TCP 2222 from 0.0.0.0/0
allow TCP 22 from 管理元IPのみ
deny  TCP 5601
deny  TCP 9200
deny  TCP 5044
```

## 4. EC2 側で repo を起動する

EC2 側の repo root:

```bash
make cowrie-live-up
make cowrie-ps
```

期待する service:

- `cowrie`
- `zeek-cowrie-live`

remote shipper まで含める場合は、後述の `make cowrie-live-shipper-up` を使う。

## 5. EC2 側の確認

Cowrie に対して外から接続試行が来ると、少なくとも次が増える。

```text
data/logs/zeek/live/cowrie/current/conn.log
```

簡単な確認:

```bash
ls -l data/logs/zeek/live/cowrie/current/conn.log
tail -n 5 data/logs/zeek/live/cowrie/current/conn.log
```

## 6. local PC 側の起動

local PC 側 repo root:

```bash
make elk-up-cowrie-live
make kibana-import-cowrie-live-dashboard
make elk-ps
```

Kibana で開くもの:

- `Cowrie Live Attack Monitoring`

## 7. リアルタイム転送について

現在の推奨は、EC2 側で Zeek が生成した `conn.log` を Filebeat shipper が 1 行ごとに local ELK の Elasticsearch へ送る構成である。

### 7-1. local ELK 側の準備

local PC 側では先に次を行う。

```bash
make elk-up-cowrie-live
make kibana-import-cowrie-live-dashboard
make es-create-cowrie-live-shipper-user
```

### 7-2. CA 証明書を EC2 側へ渡す

`adids-elk` 側で生成された CA 証明書を、EC2 側 repo の次へ配置する。

```text
filebeat/certs/ca/ca.crt
```

### 7-3. shipper 用 env を作る

EC2 側で `.env.shipper.example` を `.env.shipper` にコピーし、ELK 側の private endpoint と、`make es-create-cowrie-live-shipper-user` が出力した認証情報を入れる。

```bash
cp .env.shipper.example .env.shipper
```

### 7-4. Cowrie + Zeek + shipper を起動する

```bash
make cowrie-live-shipper-up
make cowrie-ps
```

これで、`data/logs/zeek/live/cowrie/current/conn.log` に新しい行が追加されるたび、EC2 側 Filebeat が `zeek-cowrie-live-*` へ送る。

fallback として、Tailscale 経由のファイル転送で `conn.log` を local 側へ届け、`adids-elk` 側の local ingest を使う方法も残る。

## 8. 発表前チェックリスト

- EC2 で `make cowrie-ps` が `Up`
- `data/logs/zeek/live/cowrie/current/conn.log` が更新されている
- local PC で `make elk-ps` が `Up`
- Kibana の `Cowrie Live Attack Monitoring` が開ける
- `zeek-cowrie-live-*` に document がある

## 9. 当日トラブル時の優先順位

1. local Demo2 は単独で成立させる
2. AWS 側は pre-collected logs と dashboard を使って説明する
3. EC2 から live traffic が見えていれば十分で、転送導線の完璧さは後回しにする
