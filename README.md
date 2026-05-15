# adids-honeypots

`adids-honeypots` は、公開ハニーポット群を独立運用するための repo である。

現在は次を扱う。

- Cowrie SSH honeypot
- Cowrie 宛 traffic を観測する Zeek live capture

この repo は IDS 本体を含まない。
出力契約は主に次である。

- `cowrie/var/log/cowrie/cowrie.json`
- `data/logs/zeek/live/cowrie/current/conn.log`

これらを別 repo の ELK や IDS 側へ転送・取り込みする。

## よく使うコマンド

```bash
make cowrie-up
make cowrie-live-up
make cowrie-ps
make cowrie-down
```
