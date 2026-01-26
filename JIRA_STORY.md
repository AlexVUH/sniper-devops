# JIRA Story - sniper-devops: Documentação e Implementação Completa

## 📋 Epic
**Desenvolvimento do Sistema sniper-devops**

---

## Story 1: Documentar Arquitetura e Módulos Existentes

### 🎯 Objetivo
Documentar completamente a arquitetura, módulos existentes, funções e fluxo do sistema sniper-devops.

### 📝 Descrição

O **sniper-devops** é uma ferramenta CLI para gerenciar bloqueio de IP usando ipset e iptables em Linux. Esta story documenta toda a implementação atual e estabelece a base para as próximas features.

### ✅ Critérios de Aceitação

- [x] Documentação de estrutura de diretórios
- [x] Documentação de cada módulo (core, validate, log, utils, fw)
- [x] Documentação técnica de todas as funções
- [x] Diagramas de fluxo (ADD, whitelist, validação, CIDR)
- [x] Documentação de logs estruturados (JSON Lines)
- [x] Documentação de exit codes
- [x] Troubleshooting e FAQs
- [x] Exemplos de uso completos
- [x] README.md atualizado no GitHub

### 📌 Componentes Documentados

#### **1. sniper.sh** - CLI Principal (Dispatcher)
- Dispatcher central que recebe comandos
- Extrai flags `--debug`, `--force`, `--autoblock`
- Delega para módulos específicos
- **Status**: ✅ Completo

#### **2. lib/core.sh** - Núcleo do Sistema
Funções:
- `debug()` - Saída de debug formatada
- `core_setup_colors()` - Gerenciamento de cores ANSI
- `core_acquire_lock()` - Lock com flock
- `require_root()` - Validação de permissões
- `require_cmds()` - Verificação de dependências
- **Status**: ✅ Completo

#### **3. lib/validate.sh** - Validação e Matching
Funções:
- `is_valid_ip_or_cidr()` - Validação sintática
- `ip_to_int()` - Conversão IP para inteiro
- `cidr_to_range()` - Cálculo de range CIDR
- `ip_in_cidr()` - Verificação se IP está em CIDR
- `whitelist_match_reason()` - Match com whitelist (JSON)
- **Status**: ✅ Completo

#### **4. lib/log.sh** - Sistema de Logs
Funções:
- `log_block()` - Log TXT legado
- `log_event()` - Log JSON estruturado para LogCenter
- **Status**: ✅ Completo

#### **5. lib/utils.sh** - Utilitários Firewall
Funções:
- `check_ipset_exists()` - Verifica ipset
- `ensure_iptables_rule()` - Cria/valida regra iptables
- **Status**: ✅ Completo

#### **6. fw/fw.sh** - Dispatcher Firewall
- Normaliza argumentos
- Extrai flags localmente
- Valida comando (list/flush)
- **Status**: ✅ Completo

#### **7. fw/blacklist.sh** - Motor Principal
Operações:
- `add` - Adicionar IP com validação e whitelist
- `del` - Remover do bloqueio
- `check` - Verificar status
- `list` - Listar bloqueados
- `flush` - Limpar blacklist
- **Status**: ✅ Completo

#### **8. conf/sniper.conf** - Configuração Central
- SET_NAME, TIMEOUT
- Diretórios de log
- WHITELIST_ENABLED
- ENVIRONMENT, SCRIPT_VERSION
- **Status**: ✅ Completo

#### **9. conf/whitelist.json** - Whitelist
- Redes RFC1918
- Cloudflare, Zscaler
- VPN/Proxies corporativos
- **Status**: ✅ Completo

### 🧪 Testes de Homologação Atuais

```
Total: 39 testes
PASS: 35
FAIL: 4 (comportamento esperado)
```

**Testes cobertos:**
- ✅ Validação IP/CIDR (válidos e inválidos)
- ✅ Operações básicas (add/del/check)
- ✅ Comportamento com whitelist
- ✅ Override com --force
- ✅ Modo automático --autoblock
- ✅ Debug mode --debug
- ✅ Exit codes
- ✅ Idempotência

### 📦 Instalação

**Pré-requisitos:**
```bash
sudo apt-get install -y ipset iptables jq
```

**Setup inicial:**
```bash
sudo ipset create blacklist hash:net timeout 1800
sudo iptables -I INPUT -m set --match-set blacklist src -j DROP
```

**Execução:**
```bash
chmod +x sniper.sh fw/*.sh lib/*.sh
sudo ./sniper.sh fw <IP|CIDR> add
```

### 📊 Estrutura de Logs

**TXT (legado):**
```
2026-01-26 14:32:05 192.168.1.0
```

**JSON Lines (LogCenter):**
```json
{
  "datetime": "2026-01-26T14:32:05Z",
  "action": "add",
  "ip": "10.1.2.3",
  "set": "blacklist",
  "result": "blocked",
  "source": "manual|auto",
  "user": "root",
  "whitelist_override": true,
  "timeout_sec": 1800,
  "previous_whitelist_reason": "RFC1918"
}
```

### 🎯 Exit Codes

```
0   Sucesso
1   Erro genérico
2   IP/CIDR inválido
3   ipset não existe
4   IP já bloqueado
5   IP não está bloqueado
6   Bloqueado pela whitelist
```

### 📚 Deliverables

- [x] README.md completo (900+ linhas)
- [x] Documentação técnica de funções
- [x] Diagramas de fluxo
- [x] Exemplos de uso
- [x] Troubleshooting
- [x] Commit no GitHub

### 🔗 Referências

- GitHub: https://github.com/AlexVUH/sniper-devops
- Commit: c48d976
- Branch: main

---

## Story 2: Implementar Módulo "tail" para Monitoramento de Logs

### 🎯 Objetivo
Implementar módulo de monitoramento de logs para detectar IPs suspeitos em arquivos de log e criar bloqueios automáticos.

### 📝 Descrição

Criar funcionalidade `./sniper tail` para:
1. Monitorar arquivos de log em tempo real (Apache, Nginx, OpenResty)
2. Aplicar filtros configuráveis
3. Detectar padrões de ataque
4. Fazer bloqueios automáticos com `--autoblock`
5. Integração com LogCenter para recepcionar IPs via LLM

### ✅ Critérios de Aceitação

- [ ] Comando `./sniper tail list` - Listar logs monitorados
- [ ] Comando `./sniper tail <LOG_FILE>` - Monitorar arquivo específico
- [ ] Comando `./sniper tail <IP>` - Rastrear atividades do IP
- [ ] Suporte a parsers: Apache, Nginx, OpenResty
- [ ] Filtros configuráveis (status, padrão, threshold)
- [ ] Integração com SIEM/LogCenter
- [ ] Testes de homologação

### 📋 Sub-tasks

#### 2.1: Criar Parser de Logs

**Arquivo:** `detectors/log_format.sh`

```bash
detect_log_format() {
  # Detecta tipo de log (Apache, Nginx, OpenResty)
  # Retorna: apache|nginx|openresty|unknown
}

parse_apache_log() {
  # Parse de log Apache/cPanel
  # Extrai: IP, timestamp, método, URI, status, user-agent
}

parse_nginx_log() {
  # Parse de log Nginx
  # Extrai: IP, timestamp, método, URI, status
}

parse_openresty_log() {
  # Parse de log OpenResty
  # Extrai: IP, timestamp, método, URI, status, latência
}
```

#### 2.2: Criar Filtros Comuns

**Arquivo:** `tail/common.sh`

```bash
filter_by_ip() {
  # Filtra logs por IP específico
}

filter_by_status() {
  # Filtra por status HTTP (4xx, 5xx, etc)
}

filter_by_pattern() {
  # Filtra por padrão regex (SQL injection, LFI, etc)
}

filter_by_threshold() {
  # Filtra por número de requisições em período
}
```

#### 2.3: Implementar Comando "tail"

**Arquivo:** `tail/tail.sh` (novo)

```bash
# Uso 1: Monitorar arquivo
./sniper tail /var/log/apache2/access.log

# Uso 2: Rastrear IP
./sniper tail 192.168.1.100

# Uso 3: Listar monitorados
./sniper tail list

# Uso 4: Monitor com filtros
./sniper tail /var/log/apache2/access.log --status 4xx --autoblock
./sniper tail /var/log/nginx/access.log --pattern "union select" --autoblock
```

#### 2.4: Implementar Bloqueio Automático

**Opções:**

**A) Parâmetros Pré-estabelecidos:**
```bash
# Configuração em conf/tail.conf
TAIL_STATUS_BLOCK="400,401,403,429"
TAIL_THRESHOLD="10"          # requisições
TAIL_THRESHOLD_WINDOW="5m"   # em 5 minutos
TAIL_AUTO_BLOCK="1"          # 1=sim, 0=não

# Exemplo: Bloquear após 10 requisições 403 em 5 minutos
./sniper tail /var/log/apache2/access.log --auto
```

**B) Integração com LogCenter/LLM:**
```bash
# Receber IPs do LogCenter via API/arquivo
./sniper tail --from-logcenter

# Poll a cada 30 segundos
while true; do
  curl -s https://logcenter/api/malicious-ips | jq -r '.ips[]' | while read ip; do
    sudo ./sniper fw "$ip" add --autoblock
  done
  sleep 30
done
```

#### 2.5: Testes de Homologação

- [ ] Test 01: Detectar tipo de log (apache)
- [ ] Test 02: Detectar tipo de log (nginx)
- [ ] Test 03: Detectar tipo de log (openresty)
- [ ] Test 04: Parse Apache correto
- [ ] Test 05: Parse Nginx correto
- [ ] Test 06: Parse OpenResty correto
- [ ] Test 07: Filtrar por IP
- [ ] Test 08: Filtrar por status 4xx
- [ ] Test 09: Filtrar por padrão regex
- [ ] Test 10: Filtrar por threshold
- [ ] Test 11: Monitor tempo real com tail -f
- [ ] Test 12: Bloqueio automático após threshold
- [ ] Test 13: Integração LogCenter (mock)
- [ ] Test 14: Rastrear atividades do IP (tail <IP>)
- [ ] Test 15: Exit codes corretos

### 🔧 Tecnologias

- `tail -f` - Monitoramento em tempo real
- `awk` - Parse de logs (já existem parsers)
- `grep/sed` - Filtros e transformações
- `curl` - Integração com LogCenter
- `jq` - Parse de JSON

### 📝 Arquivos a criar/modificar

**Criar:**
- `tail/tail.sh` (dispatcher)
- `conf/tail.conf` (configuração)
- `scripts/tail-test.sh` (testes)

**Modificar:**
- `detectors/log_format.sh` (implementar detector)
- `tail/common.sh` (implementar filtros)
- `tail/apache.awk` (melhorar parser)
- `tail/openresty.awk` (melhorar parser)
- `sniper.sh` (adicionar comando "tail")

### 📊 Saída Esperada

```bash
$ ./sniper tail /var/log/apache2/access.log --status 403 --threshold 5 --window 1m --autoblock

[TAIL][14:32:05] Monitorando: /var/log/apache2/access.log
[TAIL][14:32:05] Filtros: status=403, threshold=5/1m, autoblock=sim

192.168.1.100 | 5 requisições 403 em 1m | BLOQUEADO ✅
192.168.1.101 | 3 requisições 403 em 1m | OK
192.168.1.102 | 8 requisições 403 em 1m | BLOQUEADO ✅

[TAIL][14:32:10] Total bloqueados: 2
[TAIL][14:32:10] Logs estruturados em: /export/logs/sniper-tail.json
```

---

## Story 3: Implementar Bloqueios Automáticos via Parâmetros

### 🎯 Objetivo
Criar sistema de configuração de regras de bloqueio automático baseado em parâmetros pré-estabelecidos.

### 📝 Descrição

Estender a funcionalidade de `--autoblock` com regras configuráveis para diferentes cenários:
- Bloqueio por taxa de requisição
- Bloqueio por status HTTP
- Bloqueio por padrão de ataque
- Bloqueio por geolocalização

### ✅ Critérios de Aceitação

- [ ] Arquivo `conf/autoblock.conf` com regras
- [ ] Função `load_autoblock_rules()`
- [ ] Função `evaluate_autoblock_rule()`
- [ ] Comando `./sniper autoblock list`
- [ ] Comando `./sniper autoblock test <IP>`
- [ ] Integração com `tail` module
- [ ] Testes de homologação

### 📋 Estrutura de Regras

**Arquivo: `conf/autoblock.conf`**

```bash
# Regra 1: Muitas requisições
RULE_RATE_LIMIT="1"
RATE_LIMIT_THRESHOLD="100"      # requisições
RATE_LIMIT_WINDOW="1m"          # em 1 minuto
RATE_LIMIT_BLOCK="1"            # blocar automaticamente

# Regra 2: Status HTTP
RULE_HTTP_STATUS="1"
HTTP_STATUS_BLOCK="403,429,500" # status codes
HTTP_STATUS_COUNT="5"           # ocorrências
HTTP_STATUS_WINDOW="5m"
HTTP_STATUS_BLOCK_AUTO="1"

# Regra 3: Padrões de ataque
RULE_ATTACK_PATTERN="1"
ATTACK_PATTERNS="union select|exec\(|drop table|<script"
ATTACK_PATTERN_COUNT="1"        # qualquer uma
ATTACK_PATTERN_BLOCK_AUTO="1"

# Regra 4: Geolocalização
RULE_GEO_BLOCK="0"
BLOCKED_COUNTRIES="KP,CN"       # Coreia do Norte, China
GEO_BLOCK_AUTO="0"
```

### 🔧 Implementação

**Arquivo: `lib/autoblock.sh`**

```bash
load_autoblock_rules() {
  # Carrega conf/autoblock.conf
  # Valida regras
}

evaluate_autoblock_rule() {
  local ip="$1"
  local logs="$2"  # arquivo de log
  
  # Avalia cada regra ativa
  # Retorna: 0 (não bloquear) ou 1 (bloquear)
}

count_requests_for_ip() {
  local ip="$1"
  local logs="$2"
  local window="$3"
  
  # Conta requisições do IP no período
}

count_status_for_ip() {
  local ip="$1"
  local status="$2"
  local logs="$3"
  local window="$4"
}

detect_attack_pattern() {
  local ip="$1"
  local logs="$2"
  
  # Procura padrões configurados
}
```

---

## Story 4: Integração com LogCenter e LLM

### 🎯 Objetivo
Integrar sistema com LogCenter para receber análises de LLM e fazer bloqueios automáticos.

### 📝 Descrição

Criar mecanismo para:
1. Consultar API do LogCenter
2. Receber lista de IPs maliciosos analisados por LLM
3. Fazer bloqueios automáticos
4. Registrar fonte da análise

### ✅ Critérios de Aceitação

- [ ] Função `fetch_from_logcenter()`
- [ ] Parser de resposta JSON
- [ ] Validação de IPs recebidos
- [ ] Log de origem (logcenter_llm)
- [ ] Retry em caso de falha
- [ ] Modo daemon/cron

### 📋 Fluxo

```
LogCenter API
    ↓
LLM Analysis
    ↓
Resultado: {"status":"success","ips":["1.2.3.4","5.6.7.8"],"reason":"exploit_attempt"}
    ↓
sniper fw 1.2.3.4 add --autoblock --source logcenter_llm
sniper fw 5.6.7.8 add --autoblock --source logcenter_llm
    ↓
Logs com "source":"logcenter_llm"
```

### 🔧 Implementação

**Arquivo: `lib/logcenter.sh`**

```bash
fetch_from_logcenter() {
  local api_url="$1"
  local api_key="$2"
  
  # GET $api_url/api/malicious-ips
  # Return: JSON com IPs
}

parse_logcenter_response() {
  local response="$1"
  
  # Parse JSON
  # Retorna: IP | REASON (um por linha)
}

block_from_logcenter() {
  local api_url="$1"
  local api_key="$2"
  
  # Fetch IPs
  # Para cada IP:
  #   - Valida
  #   - Verifica se já está bloqueado
  #   - Faz o bloqueio com source=logcenter_llm
}
```

---

## 📚 Documentação Necessária

- [ ] ARCHITECTURE.md - Visão geral completa
- [ ] INSTALL.md - Guia de instalação detalhado
- [ ] MODULES.md - Documentação de cada módulo
- [ ] API.md - Integração com LogCenter
- [ ] TESTING.md - Guia de testes
- [ ] TROUBLESHOOTING.md - Resolução de problemas

---

## 🎯 Roadmap Consolidado

### Phase 1: ✅ Documentação (COMPLETO)
- [x] Documentar arquitetura
- [x] Documentar módulos existentes
- [x] Criar README.md completo
- [x] Fazer commit no GitHub

### Phase 2: 🔄 Módulo Tail (EM DESENVOLVIMENTO)
- [ ] Implementar detectores de log
- [ ] Implementar filtros
- [ ] Implementar comando tail
- [ ] Testes de homologação
- [ ] Documentação

### Phase 3: ⏳ Bloqueios Automáticos (PLANEJADO)
- [ ] Sistema de regras
- [ ] Avaliação de regras
- [ ] Integração com tail
- [ ] Testes
- [ ] Documentação

### Phase 4: ⏳ LogCenter Integration (PLANEJADO)
- [ ] Integração com API
- [ ] Parser de respostas
- [ ] Modo daemon
- [ ] Testes
- [ ] Documentação

### Phase 5: ⏳ Features Adicionais (BACKLOG)
- IPv6 na whitelist
- Persistência entre reboots (ipset save)
- Makefile (make smoke, make ci)
- GitHub Actions CI/CD
- Dashboard web

---

## 📊 Métricas de Sucesso

- Documentação 100% completa
- Cobertura de testes > 90%
- Exit codes consistentes
- Logs estruturados e auditáveis
- CI/CD automático no GitHub
- Suporte a múltiplos formatos de log
- Integração com SIEM/LogCenter

---

## 📝 Notas

- Manter compatibilidade com scripts existentes
- Seguir padrões de código já estabelecidos
- Documentar ao implementar
- Testes antes de commit
- Commits atômicos com mensagens descritivas

---

## 👥 Responsabilidades

| Item | Responsável | Status |
|------|-------------|--------|
| Story 1 (Docs) | Team | ✅ Done |
| Story 2 (Tail) | Backlog | ⏳ Next |
| Story 3 (Autoblock) | Backlog | ⏳ Future |
| Story 4 (LogCenter) | Backlog | ⏳ Future |

---

## 🔗 Links Relacionados

- Repository: https://github.com/AlexVUH/sniper-devops
- Issues: https://github.com/AlexVUH/sniper-devops/issues
- Discussions: https://github.com/AlexVUH/sniper-devops/discussions

