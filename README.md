# potter

`potter` は、公開ハニーポット群を独立運用するための repo である。

現在は次を扱う。

- Cowrie SSH honeypot
- Cowrie 宛 traffic を観測する Zeek live capture

この repo は IDS 本体を含まない。
出力契約は主に次である。

- `cowrie/var/log/cowrie/cowrie.json`
- `data/logs/zeek/live/cowrie/current/conn.log`

これらを別 repo の ELK や IDS 側へ転送・取り込みする。

## 推奨アーキテクチャ

ConoHa などの公開 VPS をセンサとして使い、利用可能なマシンが `公開VPS` と `手元PC` の 2 台だけである場合、推奨は `VPS 収集専用 + 手元PC pull` 構成である。

```text
                Internet attackers
                        |
                        v
+---------------------------------------------------+
| Public VPS / Sensor                               |
|                                                   |
|  Cowrie 公開待受 (既定 22/tcp)                    |
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
                        | every 1m or 5m
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

- 公開 VPS が侵害された場合でも、`手元PC の送り先情報` を VPS に残さずに済む
- `cowrie + zeek` に責務を絞れるため、センサ側の運用が単純になる
- `conn.log` は VPS 側に残るため、手元PC 復旧後に追いつける

現在の既定構成は `Cowrie 公開待受 = 22/tcp`, `管理用 SSH = 443/tcp` である。
この repo は公開センサホスト専用であり、`make up` は `.potter-sensor-host` marker が無い host では拒否される。
初回だけ、承認済みの公開センサホスト上で `make sensor-host-init` を実行してから `make up` を使う。

詳細は [公開VPSセンサーノード準備手順](/home/mnl/adids/potter/docs/公開VPSセンサーノード準備手順.md:1) を参照。

## よく使うコマンド

```bash
make sensor-host-init
make up
make ps
make down
```
