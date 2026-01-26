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
- **Validação avançada de IPv4/CIDR** com conversão numérica
- **Sistema de lock** para evitar execuções simultâneas

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
sudo ./sniper.sh fw 192.168.0.0/24 add
```

### Forçar inclusão (ignorar whitelist)
```bash
sudo ./sniper.sh fw 10.1.2.3 add --force
```

### Modo automático (para cron/jobs)
```bash
sudo ./sniper.sh fw 1.2.3.4 add --autoblock
```

### Verificar se está bloqueado
```bash
./sniper.sh fw 8.8.8.8 check
```

### Remover do bloqueio
```bash
sudo ./sniper.sh fw 8.8.8.8 del
```

### Listar todos os bloqueados
```bash
./sniper.sh fw list
```

### Esvaziar a blacklist
```bash
sudo ./sniper.sh fw flush
```

### Debug (mostra apenas [DEBUG] messages)
```bash
./sniper.sh fw --debug 8.8.8.8 add
```

### Combinando flags
```bash
sudo ./sniper.sh fw --debug 10.1.2.3 add --force --autoblock
```

---

## Documentação Técnica das Funções

### 📦 **lib/core.sh** - Núcleo do Sistema

#### `debug()`
Imprime mensagens de debug apenas quando `DEBUG=1`.

```bash
# Uso
debug "Mensagem de debug"

# Formato de saída
[DEBUG][2026-01-26 14:32:05] Mensagem de debug
```

**Parâmetros:**
- `$1`: Mensagem a exibir

**Exit code:**
- 0: Sempre (função informativa)

---

#### `core_setup_colors()`
Ativa ou desativa cores ANSI baseado em `NO_COLOR` ou se stdout não é TTY.

```bash
# Variáveis afetadas
GREEN=""    # 0 ou vazio
YELLOW=""
RED=""
BLUE=""
CYAN=""
RESET=""
```

**Uso interno:** Chamado no início dos scripts principais.

---

#### `core_acquire_lock()`
Usa `flock` para garantir que apenas uma instância executa simultaneamente.

```bash
# Usa arquivo de lock (configurável em sniper.conf)
LOCK_FILE="/tmp/sniper-devops.lock"

# Se já estiver rodando:
# - Registra no LOG_TXT: "sniper-devops já está rodando"
# - Exit code 0 (não falha, apenas ignora)
```

**Exit codes:**
- 0: Lock adquirido com sucesso OU já estava rodando
- 1: Falha ao criar arquivo de lock

---

#### `require_root()`
Valida se script executa como `root`.

```bash
# Uso
require_root

# Se não root:
# Erro: execute como root
# Exit code 1
```

---

#### `require_cmds()`
Verifica se comandos necessários existem no sistema.

```bash
# Uso
require_cmds ipset iptables jq

# Se faltar algum:
# Dependências ausentes: jq
# Exit code 1

# Exit codes
0  Todos os comandos existem
1  Pelo menos um comando ausente
```

---

### 📝 **lib/validate.sh** - Validação e Matching

#### `is_valid_ip_or_cidr()`
Valida sintaxe de IPv4 ou CIDR (IPv4).

```bash
# Aceita
is_valid_ip_or_cidr "8.8.8.8"         # ✅
is_valid_ip_or_cidr "192.168.0.0/16"  # ✅
is_valid_ip_or_cidr "10.0.0.0/8"      # ✅

# Rejeita
is_valid_ip_or_cidr "8.8.8.257"       # ❌ octeto > 255
is_valid_ip_or_cidr "192.168.0.0/33"  # ❌ máscara > 32
is_valid_ip_or_cidr "192.168.0"       # ❌ incompleto
```

**Parâmetros:**
- `$1`: String a validar (IP ou CIDR)

**Exit codes:**
- 0: Válido
- 1: Inválido

**Validações:**
- Octetos: 0-255 cada
- Máscara CIDR: 0-32

---

#### `ip_to_int()`
Converte IP dotted para inteiro não assinado 32-bit.

```bash
# Uso
ip_to_int "1.2.3.4"
# Saída: 16909060

# Cálculo
# 1 << 24 + 2 << 16 + 3 << 8 + 4
# = 16777216 + 131072 + 768 + 4
# = 16909060
```

**Parâmetros:**
- `$1`: IP em formato dotted (ex: 192.168.1.1)

**Saída:** Inteiro (decimal)

**Uso interno:** Necessário para `ip_in_cidr()`

---

#### `cidr_to_range()`
Dado um CIDR, retorna intervalo `start end` (ambos como inteiros).

```bash
# Uso
cidr_to_range "192.168.1.0/24"
# Saída: 3232235776 3232236031

# Cálculo do range /24
# - Start: 192.168.1.0 = 3232235776
# - End: 192.168.1.255 = 3232236031
# - Tamanho: 256 hosts

# IP sem máscara (tratado como /32)
cidr_to_range "8.8.8.8"
# Saída: 134744072 134744072  (um único IP)
```

**Parâmetros:**
- `$1`: CIDR (ex: 10.0.0.0/8) ou IP (ex: 8.8.8.8)

**Saída:** "start end" (separados por espaço)

**Cálculo:**
- `host_bits = 32 - mask`
- `size = 2 ^ host_bits`
- `start = (ip_int >> host_bits) << host_bits`
- `end = start + size - 1`

---

#### `ip_in_cidr()`
Retorna 0 se IP está dentro do CIDR, senão 1.

```bash
# Uso
if ip_in_cidr "192.168.1.50" "192.168.1.0/24"; then
  echo "IP está no CIDR"
fi

# Exemplos
ip_in_cidr "10.0.0.5" "10.0.0.0/8"     # ✅ exit 0
ip_in_cidr "10.1.1.1" "10.0.0.0/8"     # ✅ exit 0 (em 10.x.x.x)
ip_in_cidr "8.8.8.8" "10.0.0.0/8"      # ❌ exit 1
ip_in_cidr "192.168.1.1" "192.168.1.1" # ✅ exit 0 (IP = /32)
```

**Parâmetros:**
- `$1`: IP a verificar
- `$2`: CIDR para comparar

**Exit codes:**
- 0: IP está no CIDR
- 1: IP fora do CIDR ou erro

**Usa:**
- `ip_to_int()` para converter IP
- `cidr_to_range()` para obter limites

---

#### `whitelist_match_reason()`
Lê `conf/whitelist.json` e retorna motivo se IP está listado.

```bash
# Uso
reason=$(whitelist_match_reason "10.1.2.3")
if [[ -n "$reason" ]]; then
  echo "IP bloqueado por: $reason"
fi

# Saída (exemplos)
echo "RFC1918"          # IP está em 10.0.0.0/8
echo "Cloudflare"      # IP está em 172.64.0.0/13
echo ""                # IP não encontrado
```

**Parâmetros:**
- `$1`: IP ou CIDR a verificar

**Saída:** String com motivo (ou vazio se não encontrado)

**Dependências:**
- `jq` (sem jq, retorna vazio silenciosamente)
- `WHITELIST_ENABLED` deve ser "1"
- `WHITELIST_JSON` deve ser arquivo válido

**Comportamento:**
- Se CIDR, usa apenas o IP base (parte antes de `/`)
- JSON inválido: ignora whitelist (não falha)
- jq ausente: ignora whitelist (não falha)
- Arquivo não existe: retorna vazio

---

### 📊 **lib/log.sh** - Sistema de Logs

#### `log_block()`
Log legado (TXT) de IP bloqueado.

```bash
# Uso
log_block "192.168.1.0"

# Formato em /export/logs/sniper-devops.log
2026-01-26 14:32:05 192.168.1.0
```

**Parâmetros:**
- `$1`: IP bloqueado

**Arquivo:** `LOG_TXT` (configurável)

**Formato:** `YYYY-MM-DD HH:MM:SS <IP>`

---

#### `log_event()`
Log estruturado (JSON Lines) para LogCenter/SIEM. **Apenas ação "add" é registrada.**

```bash
# Uso completo
log_event "add" "10.1.2.3" "blocked" "1800" "manual" "" "1" "RFC1918"

# Parâmetros
# $1 = action      ("add" | outros ignorados)
# $2 = ip          (obrigatório)
# $3 = result      ("blocked" | "already_blocked" | "error")
# $4 = timeout_sec (1800, etc. - opcional)
# $5 = source      ("manual" | "auto" - default "manual")
# $6 = user        ($(whoami) se vazio)
# $7 = wl_override (0|1|true|false - default 0)
# $8 = prev_reason (motivo da whitelist, ex: "RFC1918")
```

**Saída JSON (exemplo):**
```json
{
  "datetime": "2026-01-26T14:32:05Z",
  "action": "add",
  "ip": "10.1.2.3",
  "set": "blacklist",
  "result": "blocked",
  "host": "servidor01",
  "env": "prod",
  "script": "sniper-devops",
  "script_version": "0.1.0",
  "schema": 1,
  "source": "auto",
  "user": "root",
  "whitelist_override": true,
  "timeout_sec": 1800,
  "previous_whitelist_reason": "RFC1918"
}
```

**Arquivo:** `LOG_JSON` (configurável)

**Notas:**
- Apenas action="add" gera eventos no LogCenter
- Timestamps em ISO8601 UTC
- User resolução: `$SUDO_USER` → `id -un` → `whoami`
- Reason é escapada para JSON (aspas)

---

### 🔧 **lib/utils.sh** - Utilitários Firewall

#### `check_ipset_exists()`
Verifica se ipset foi criado.

```bash
# Uso
if check_ipset_exists; then
  echo "ipset blacklist existe"
else
  echo "ipset não existe (exit 1)"
fi

# Exit codes
0  ipset existe
1  ipset não existe
```

**Saída ao usuário (se não existe):**
```
Aviso: ipset "blacklist" não existe
Crie com:
ipset create blacklist hash:net timeout 1800
```

---

#### `ensure_iptables_rule()`
Cria regra iptables se não existir.

```bash
# Usa
ensure_iptables_rule

# Verifica
iptables -C INPUT -m set --match-set blacklist src -j DROP

# Se não existir, cria
iptables -I INPUT -m set --match-set blacklist src -j DROP
```

**Variáveis usadas:**
- `IPTABLES_CHAIN` (default: "INPUT")
- `SET_NAME` (default: "blacklist")

**Exit codes:**
- Implícito (exit 0 se sucesso, 1 se falha)

---

### 🚀 **fw/fw.sh** - Dispatcher Firewall

Parser e normalizador de argumentos. Extrai flags (`--debug`, `--force`, `--autoblock`) e encaminha para `blacklist.sh`.

**Fluxo:**
```
sniper.sh fw --debug 8.8.8.8 add --force
    ↓
fw.sh (extrai --debug, --force; exporta como env)
    ↓
blacklist.sh (recebe ação/IP/cmd)
```

**Validações:**
- `list` e `flush` NÃO aceitam parâmetros extra
- ❌ `sniper.sh fw 1.2.3.4 list`
- ✅ `sniper.sh fw list`

---

### ⚡ **fw/blacklist.sh** - Motor Principal

Executa operações de bloqueio: add, del, check, list, flush.

#### Fluxo: ADD (Adicionar IP ao bloqueio)
```
1. Valida IP com is_valid_ip_or_cidr()
2. check_ipset_exists()
3. Verifica whitelist (se WHITELIST_ENABLED=1)
   ├─ Se bloqueado (sem --force) → exit 6
   └─ Se --force → registra override no log
4. ensure_iptables_rule()
5. ipset test (já bloqueado?)
   ├─ Sim → exit 4 (idempotente)
   └─ Não → ipset add
6. log_block() (TXT)
7. log_event() (JSON com todos os detalhes)
```

#### Fluxo: DEL (Remover do bloqueio)
```
1. Valida IP
2. check_ipset_exists()
3. ipset test (está bloqueado?)
   ├─ Não → exit 5
   └─ Sim → ipset del
4. Retorna exit 0
```

#### Fluxo: CHECK (Verificar status)
```
1. Valida IP
2. check_ipset_exists()
3. ipset test
   ├─ Sim → "IP está bloqueado" (exit 0)
   └─ Não → "IP não está bloqueado" (exit 5)
```

#### Fluxo: LIST (Listar bloqueados)
```
1. check_ipset_exists()
2. ipset list blacklist | awk (extrai seção "Members:")
3. Modo DEBUG: exibe cada linha com [DEBUG]
4. Modo normal: exibe completo
```

#### Fluxo: FLUSH (Limpar tudo)
```
1. check_ipset_exists()
2. ipset flush
3. "Blacklist esvaziada"
```

---

## Logs Estruturados (JSON Lines)

### Formato Completo
```json
{
  "datetime": "2026-01-26T14:32:05Z",
  "action": "add",
  "ip": "10.1.2.3",
  "set": "blacklist",
  "result": "blocked",
  "host": "servidor01",
  "env": "prod",
  "script": "sniper-devops",
  "script_version": "0.1.0",
  "schema": 1,
  "source": "manual|auto",
  "user": "root|sudo_user",
  "whitelist_override": true|false,
  "timeout_sec": 1800,
  "previous_whitelist_reason": "RFC1918"
}
```

### Campos
| Campo | Descrição | Exemplo |
|-------|-----------|---------|
| datetime | ISO8601 UTC | "2026-01-26T14:32:05Z" |
| action | Ação (apenas "add" é logado) | "add" |
| ip | IP ou CIDR bloqueado | "10.1.2.3" ou "192.168.0.0/24" |
| set | Nome do ipset | "blacklist" |
| result | Status da operação | "blocked", "already_blocked" |
| host | Nome da máquina | "servidor01" |
| env | Ambiente (de config) | "prod", "staging" |
| script | Nome do script | "sniper-devops" |
| script_version | Versão do script | "0.1.0" |
| schema | Versão do schema | 1 |
| source | Origem do bloqueio | "manual" (CLI), "auto" (cron) |
| user | Usuário que executou | "root", "admin" |
| whitelist_override | Se ignorou whitelist | true, false |
| timeout_sec | Expiração do IP | 1800 (30 min) |
| previous_whitelist_reason | Motivo da whitelist | "RFC1918", "Cloudflare" |

---

## Exit Codes

```
0   Sucesso (operação executada)
1   Erro genérico (ex: ipset add falhou)
2   Uso inválido / IP ou CIDR inválido / parâmetros incorretos
3   ipset inexistente (não foi criado)
4   IP já bloqueado (tentativa idempotente)
5   IP não está bloqueado (tentativa de remover não existente)
6   Barrado pela whitelist (blocked_by_whitelist)
```

---

## Diagramas de Fluxo

### Fluxo Geral: ADD
```
sniper.sh fw 8.8.8.8 add --debug --force
    │
    ├─ Extract: --debug, --force
    ├─ Export: DEBUG=1, FORCE=1
    └─ Call: fw.sh (args: fw 8.8.8.8 add)
         │
         ├─ fw.sh: Normalize args
         └─ Call: blacklist.sh (fw, 8.8.8.8, add)
              │
              ├─ require_root()
              ├─ core_acquire_lock()
              ├─ is_valid_ip_or_cidr("8.8.8.8") → ✅
              ├─ check_ipset_exists() → ✅
              ├─ whitelist_match_reason("8.8.8.8") → empty
              ├─ ensure_iptables_rule() → ✅
              ├─ ipset test → not found
              ├─ ipset add 8.8.8.8 → ✅
              ├─ log_block("8.8.8.8")
              ├─ log_event("add", "8.8.8.8", "blocked", ...)
              └─ Exit 0
```

### Whitelist Check Flow
```
ADD 10.1.2.3
    │
    ├─ is_valid_ip_or_cidr("10.1.2.3") → ✅
    │
    ├─ WHITELIST_ENABLED == "1"? → YES
    │
    ├─ whitelist_match_reason("10.1.2.3")
    │   │
    │   ├─ Load JSON: conf/whitelist.json
    │   ├─ For each CIDR in ipv4[]
    │   │   └─ ip_in_cidr("10.1.2.3", "10.0.0.0/8")? → YES
    │   └─ Return "RFC1918"
    │
    ├─ FORCE_ACTIVE == 1?
    │   ├─ NO → Exit 6 (blocked_by_whitelist)
    │   └─ YES → Continue (log override)
    │
    ├─ ipset add 10.1.2.3 → ✅
    ├─ log_event(..., wl_override=true, prev_reason="RFC1918")
    └─ Exit 0
```

### IP Validation Flow
```
is_valid_ip_or_cidr("192.168.1.0/24")
    │
    ├─ Regex check: ^([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?$
    │   └─ Match? → YES
    │
    ├─ Extract IP: "192.168.1.0"
    ├─ Extract Mask: "24"
    │
    ├─ For each octet in [192, 168, 1, 0]
    │   └─ 0 <= octet <= 255? → YES
    │
    ├─ Mask 0 <= 24 <= 32? → YES
    │
    └─ Return 0 (valid)
```

### CIDR Range Calculation
```
cidr_to_range("10.0.0.0/8")
    │
    ├─ ip_to_int("10.0.0.0") → 167772160
    ├─ host_bits = 32 - 8 = 24
    ├─ size = 2^24 = 16777216
    ├─ start = (167772160 >> 24) << 24 = 167772160
    ├─ end = 167772160 + 16777216 - 1 = 184549375
    │
    └─ Return "167772160 184549375"
       └─ Range contains: 10.0.0.0 to 10.255.255.255
```

---

## Smoke-test (`scripts/smoke-test.sh`)

Executar suite completa de testes:

```bash
chmod +x scripts/smoke-test.sh
./scripts/smoke-test.sh
```

Saída esperada:
```
Resumo: Total=39 | PASS=35 | FAIL=4
```

Cobre:
- Validação IP/CIDR
- Operações add/del/check
- Whitelist behavior
- --force override
- --autoblock source
- Exit codes

---

## Troubleshooting

### "ipset blacklist não existe"
```bash
sudo ipset create blacklist hash:net timeout 1800
```

### "Erro: execute como root"
```bash
sudo ./sniper.sh fw 8.8.8.8 add
```

### "IP não permitido (motivo: RFC1918)"
Use `--force` para override:
```bash
sudo ./sniper.sh fw 10.1.2.3 add --force
```

### Debug não mostra mensagens
```bash
DEBUG=1 ./sniper.sh fw 8.8.8.8 add
# OU
./sniper.sh fw --debug 8.8.8.8 add
```

### Ver logs
```bash
tail -f /export/logs/sniper-devops.log    # TXT (legado)
tail -f /export/logs/sniper-devops.json   # JSON (LogCenter)
```

---

## Roadmap
- Suporte a whitelist IPv6
- Atualização automática de blocos Cloudflare/Zscaler
- Validação de staleness do `updated_at`
- Makefile (make smoke, make ci)
- Integração com GitHub Actions
- Modo soft-block (apenas registrar)
- Persistência entre reboots (usando `ipset save`)

---

## Conclusão
O **sniper-devops** é pronto para produção: auditável, automatizável e ideal para operações de segurança corporativa.
