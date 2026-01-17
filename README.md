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

## Checklist do funcionamento

``` text
checklist01:	command -v ipset iptables flock bash						resultado:	ok
checklist02:	chmod +x ./sniper.sh fw/*.sh lib/*.sh						resultado:	ok
checklist03:	ipset create blacklist hash:net timeout 1800				resultado:	ok
checklist04:	ipset list blacklist										resultado:	ok
checklist05:	ipset destroy blacklist										resultado:	ok
checklist06:	iptables -I INPUT -m set --match-set blacklist src -j DROP	resultado:	ok
checklist07:	iptables -D INPUT -m set --match-set blacklist src -j DROP	resultado:	ok
checklist08:	./sniper.sh fw 8.8.8.8 add									resultado:	ok
checklist09:	./sniper.sh fw 8.8.8.8 del									resultado:	ok
checklist10:	./sniper.sh fw 8.8.8.8 check								resultado:	ok
checklist11:	./sniper.sh fw 8.8.8.0/24 add								resultado:	ok
checklist12:	./sniper.sh fw 8.8.8.0/24 del								resultado:	ok
checklist13:	./sniper.sh fw 8.8.8.0/24 check								resultado:	ok
checklist14:	./sniper.sh fw list											resultado:	ok
checklist15:	./sniper.sh fw flush										resultado:	ok
checklist16:	./sniper.sh help											resultado:	ok
checklist17:	./sniper.sh fw help											resultado:	ok
checklist18:	./sniper.sh fw 8.8.8.257 add								resultado:	ok
checklist19:	./sniper.sh fw 8.8.8.257 del								resultado:	ok
checklist20:	./sniper.sh fw 8.8.8.257 check								resultado:	ok
checklist21:	./sniper.sh fw 8.8.8.0/33 add								resultado:	ok
checklist22:	./sniper.sh fw 8.8.8.0/33 del								resultado:	ok
checklist23:	./sniper.sh fw 8.8.8.0/33 check								resultado:	ok
checklist24:	./sniper.sh fw --debug 8.8.8.8 add							resultado:	ok
checklist25:	./sniper.sh fw --debug 8.8.8.8 del							resultado:	ok
checklist26:	./sniper.sh fw --debug 8.8.8.8 check						resultado:	ok
checklist27:	./sniper.sh fw --debug 8.8.8.0/24 add						resultado:	ok
checklist28:	./sniper.sh fw --debug 8.8.8.0/24 del						resultado:	ok
checklist29:	./sniper.sh fw --debug 8.8.8.0/24 check						resultado:	ok
checklist30:	./sniper.sh fw --debug list									resultado:	ok
checklist31:	./sniper.sh fw --debug flush								resultado:	ok
checklist32:	./sniper.sh --debug help									resultado:	ok
checklist33:	./sniper.sh fw --debug help									resultado:	ok
checklist34:	./sniper.sh fw --debug 8.8.8.257 add						resultado:	ok
checklist35:	./sniper.sh fw --debug 8.8.8.257 del						resultado:	ok
checklist36:	./sniper.sh fw --debug 8.8.8.257 check						resultado:	ok
checklist37:	./sniper.sh fw --debug 8.8.8.0/33 add						resultado:	ok
checklist38:	./sniper.sh fw --debug 8.8.8.0/33 del						resultado:	ok
checklist39:	./sniper.sh fw --debug 8.8.8.0/33 check						resultado:	ok

BUGS CONHECIDOS

regras 09 e 11 - se eu bloquear o IP 8.8.8.8 eu não consigo bloquear o bloco 8.8.8.0/24, diz que já está bloqueado

VER LOGS EM TODA AÇÃO DE ADD
