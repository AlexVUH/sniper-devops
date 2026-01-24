# sniper-devops

Ferramenta **CLI** para gerenciar bloqueio de IP usando **ipset** e **iptables**, com:

- Blacklist manual e automática
- Whitelist em **JSON** com motivos documentados
- Inclusão forçada (`--force`) com trilha de auditoria
- Modo automático (`--autoblock`) para cron/jobs
- Modo de diagnóstico limpo (`--debug`)
- **Logs estruturados (JSON Lines)** para SIEM/LogCenter
- **Smoke-test** completo para validação/CI
- Arquitetura modular em shell scripts

## Estrutura do Projeto

```text
sniper-devops/
├─ sniper.sh                     # CLI raiz (dispatcher)
├─ fw/
│  ├─ fw.sh                      # Parser/normalizador do módulo FW
│  └─ blacklist.sh               # add/del/check/list/flush + whitelist + force
├─ conf/
│  ├─ sniper.conf                # Configuração central
│  └─ whitelist.json             # Redes/IPs que não podem ser bloqueados
├─ lib/
│  ├─ core.sh                    # Debug, cores, lock, dependências
│  ├─ log.sh                     # Logs TXT + JSON estruturado
│  ├─ validate.sh                # Validação IP/CIDR + match da whitelist
│  └─ utils.sh                   # Utilitários (iptables, ipset)
├─ scripts/
│  └─ smoke-test.sh              # Testes automatizados (PASS/FAIL)
└─ export/
   └─ logs/
      ├─ sniper-devops.log       # Log TXT (legado)
      └─ sniper-devops.json      # Log JSON Lines para SIEM
```

## Instalação

```bash
sudo apt-get update
sudo apt-get install -y ipset iptables jq
```

### Criar o set e a regra de firewall (uma única vez)
```bash
sudo ipset create blacklist hash:net timeout 1800
sudo iptables -I INPUT -m set --match-set blacklist src -j DROP
```

## Configuração (`conf/sniper.conf`)

```bash
SET_NAME="blacklist"
TIMEOUT="1800"

LOG_DIR="/export/logs"
LOG_TXT="/export/logs/sniper-devops.log"
LOG_JSON="/export/logs/sniper-devops.json"

SCRIPT_VERSION="0.1.0"
ENVIRONMENT="prod"

WHITELIST_ENABLED="1"
WHITELIST_JSON="${ROOT_DIR}/conf/whitelist.json"
```

## Whitelist (`conf/whitelist.json`)

```json
{
  "version": "1.0",
  "updated_at": "2026-01-19T20:05:00Z",
  "ipv4": [
    { "cidr": "10.0.0.0/8", "nota": "RFC1918" },
    { "cidr": "172.64.0.0/13", "nota": "Cloudflare" },
    { "cidr": "170.85.0.0/16", "nota": "Proxy Zscaler" },
    { "cidr": "200.221.157.3/32", "nota": "VPN UOL" }
  ]
}
```

### Comportamento da whitelist
- Se um IP/CIDR pertence à whitelist → **a inclusão (add) é negada**.
- Mensagem ao usuário:
```
IP não permitido (motivo: X)
```
- **Exit code 6** (`blocked_by_whitelist`).

### Override (`--force`)
Permite ignorar a whitelist **explicitamente**, com auditoria completa:
```
"whitelist_override": true,
"previous_whitelist_reason": "RFC1918"
```

## Uso da CLI

### Ajuda
```bash
./sniper.sh help
./sniper.sh fw help
```

### Adicionar IP/CIDR
```bash
sudo ./sniper.sh fw 8.8.8.8 add
```

### Forçar inclusão
```bash
sudo ./sniper.sh fw 10.1.2.3 add --force
```

### Modo automático
```bash
sudo ./sniper.sh fw 1.2.3.4 add --autoblock
```

### Verificar
```bash
./sniper.sh fw 8.8.8.8 check
```

### Remover
```bash
sudo ./sniper.sh fw 8.8.8.8 del
```

### Listar
```bash
./sniper.sh fw list
```

### Esvaziar
```bash
sudo ./sniper.sh fw flush
```

### Debug
```bash
./sniper.sh fw --debug 8.8.8.8 add
```

## Logs Estruturados (JSON Lines)

Exemplo:
```json
{"datetime":"2026-01-23T23:59:10Z","action":"add","ip":"10.1.2.3","set":"blacklist","result":"blocked","host":"hostname","env":"prod","script":"sniper-devops","script_version":"0.1.0","schema":1,"source":"manual","user":"root","whitelist_override":true,"timeout_sec":1800,"previous_whitelist_reason":"RFC1918"}
```

## Exit Codes
```
0  Sucesso
1  Erro genérico
2  Uso inválido / IP ou CIDR inválido
3  ipset inexistente
4  IP já bloqueado
5  IP não está bloqueado
6  Barrado pela whitelist
```

## Smoke-test (`scripts/smoke-test.sh`)

Executar:
```bash
chmod +x scripts/smoke-test.sh
./scripts/smoke-test.sh
```

Saída:
```
Resumo: Total=X | PASS=Y | FAIL=Z
```

## Checklist Manual
```
cd /home/avitola/projects/sniper-devops
jq . conf/whitelist.json >/dev/null
sudo ipset create blacklist hash:net timeout 1800 2>/dev/null || true

./sniper.sh help
./sniper.sh fw help
./sniper.sh fw --debug list
./sniper.sh fw --debug flush
./sniper.sh fw list 8.8.8.8 ; echo $?
./sniper.sh fw 8.8.8.8 list ; echo $?

sudo ./sniper.sh fw --debug 8.8.8.8 add ; echo $?
sudo ./sniper.sh fw --debug 8.8.8.8 add ; echo $?
sudo ./sniper.sh fw --debug 8.8.8.8 check ; echo $?
sudo ./sniper.sh fw --debug 8.8.8.8 del ; echo $?

./sniper.sh fw --debug 8.8.8.257 add ; echo $?
./sniper.sh fw --debug 192.168.0.0/33 add ; echo $?

sudo ./sniper.sh fw --debug 10.1.2.3 add ; echo $?
sudo ./sniper.sh fw --debug 10.1.2.3 add --force ; echo $?
sudo ./sniper.sh fw --debug 10.1.2.3 del ; echo $?

sudo ./sniper.sh fw --debug 172.64.1.2 add ; echo $?
sudo ./sniper.sh fw --debug 170.85.0.10 add ; echo $?

./sniper.sh fw list ; echo $?
./sniper.sh fw flush ; echo $?
./sniper.sh fw --debug 1.2.3.4 check ; echo $?

tail -n 10 /export/logs/sniper-devops.json
```

## Roadmap
- Suporte a whitelist IPv6
- Atualização automática de blocos Cloudflare/Zscaler
- Validação de staleness do `updated_at`
- Makefile (make smoke, make ci)
- Integração com GitHub Actions
- Modo soft-block (apenas registrar)

## Conclusão
O **sniper-devops** é pronto para produção: auditável, automatizável e ideal para operações de segurança corporativa.
