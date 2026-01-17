## Estrutura do projeto

```text
sniper-devops/
├── sniper.sh                # CLI principal (dispatcher)
│
├── conf/
│   ├── sniper.conf          # Configurações globais
│   ├── blacklist.conf       # Configs da blacklist
│   └── whitelist.conf       # Configs da whitelist
│
├── lib/
│   ├── core.sh              # lock, debug, cores, exit codes
│   ├── validate.sh          # IP / CIDR / args
│   ├── log.sh               # log_block, json, txt
│   └── utils.sh             # helpers genéricos
│
├── fw/
│   ├── fw.sh                # dispatcher fw
│   ├── blacklist.sh         # add/del/check/list/flush blacklist
│   └── whitelist.sh         # add/del/check/list whitelist
│
├── tail/
│   ├── tail.sh              # dispatcher tail
│   ├── apache.awk           # parser apache/cpanel
│   ├── openresty.awk        # parser openresty
│   └── common.sh            # filtros (ip, since, blocked)
│
├── detectors/
│   └── log_format.sh        # detecta tipo de log
│
├── logs/
│   ├── sniper.log
│   └── sniper.json
│
└── README.md

