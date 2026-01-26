# Como Importar as Histórias para o Jira

## 📋 Opção 1: Copy/Paste Manual (Rápido)

### Story 1: Documentar Arquitetura e Módulos Existentes

**Type:** Story
**Project:** [Seu projeto]
**Summary:** `[sniper-devops] Documentar Arquitetura e Módulos Existentes`
**Priority:** High
**Status:** Done

**Description:**

```
O **sniper-devops** é uma ferramenta CLI para gerenciar bloqueio de IP usando ipset e iptables em Linux. Esta story documenta toda a implementação atual e estabelece a base para as próximas features.

## Componentes Documentados

### 1. sniper.sh - CLI Principal
- Dispatcher central que recebe comandos
- Extrai flags --debug, --force, --autoblock
- Delega para módulos específicos

### 2. lib/core.sh - Núcleo
Funções: debug(), core_setup_colors(), core_acquire_lock(), require_root(), require_cmds()

### 3. lib/validate.sh - Validação
Funções: is_valid_ip_or_cidr(), ip_to_int(), cidr_to_range(), ip_in_cidr(), whitelist_match_reason()

### 4. lib/log.sh - Sistema de Logs
Funções: log_block() (TXT), log_event() (JSON Lines)

### 5. lib/utils.sh - Utilitários
Funções: check_ipset_exists(), ensure_iptables_rule()

### 6. fw/fw.sh - Dispatcher Firewall
- Normaliza argumentos
- Extrai flags
- Valida comandos

### 7. fw/blacklist.sh - Motor Principal
Operações: add, del, check, list, flush

### 8. conf/sniper.conf - Configuração Central
Variáveis: SET_NAME, TIMEOUT, LOG_DIR, WHITELIST_ENABLED

### 9. conf/whitelist.json - Whitelist
Redes: RFC1918, Cloudflare, Zscaler, VPN corporativa

## Testes Atuais
- Total: 39
- PASS: 35
- FAIL: 4 (esperado)

Cobre: Validação, operações básicas, whitelist, --force, --autoblock, exit codes
```

**Acceptance Criteria:**

```
- [x] Documentação de estrutura de diretórios
- [x] Documentação de cada módulo
- [x] Documentação técnica de todas as funções
- [x] Diagramas de fluxo
- [x] Documentação de logs estruturados
- [x] Documentação de exit codes
- [x] Troubleshooting
- [x] Exemplos de uso
- [x] README.md atualizado no GitHub
```

**Labels:** documentation, done

**Assignee:** [Você]

**Due Date:** 2026-01-26

---

### Story 2: Implementar Módulo "tail" para Monitoramento de Logs

**Type:** Story
**Project:** [Seu projeto]
**Summary:** `[sniper-devops] Implementar Módulo "tail" para Monitoramento de Logs`
**Priority:** High
**Status:** Backlog

**Description:**

```
Implementar módulo de monitoramento de logs para detectar IPs suspeitos e criar bloqueios automáticos.

## Objetivos

1. Monitorar arquivos de log em tempo real (Apache, Nginx, OpenResty)
2. Aplicar filtros configuráveis
3. Detectar padrões de ataque
4. Fazer bloqueios automáticos com --autoblock
5. Integração com LogCenter/LLM

## Comandos

./sniper tail list                                    # Listar logs monitorados
./sniper tail /var/log/apache2/access.log            # Monitorar arquivo
./sniper tail 192.168.1.100                          # Rastrear IP
./sniper tail /var/log/apache2/access.log --status 4xx --autoblock  # Com filtros

## Sub-tasks

1. Criar parser de logs (detectors/log_format.sh)
2. Criar filtros comuns (tail/common.sh)
3. Implementar comando tail (tail/tail.sh)
4. Implementar bloqueio automático
5. Testes de homologação

## Testes Esperados

- Detectar tipos de log (apache, nginx, openresty)
- Parse correto de cada tipo
- Filtros funcionando
- Monitor em tempo real com tail -f
- Bloqueio automático após threshold
- Integração LogCenter (mock)
- Exit codes corretos
```

**Acceptance Criteria:**

```
- [ ] Comando ./sniper tail list
- [ ] Comando ./sniper tail <LOG_FILE>
- [ ] Comando ./sniper tail <IP>
- [ ] Suporte a Apache, Nginx, OpenResty
- [ ] Filtros: status, padrão, threshold
- [ ] Integração SIEM/LogCenter
- [ ] Testes de homologação (min 15)
```

**Labels:** enhancement, feature, tail-module

**Assignee:** [Você]

**Story Points:** 13

---

### Story 3: Implementar Bloqueios Automáticos via Parâmetros

**Type:** Story
**Project:** [Seu projeto]
**Summary:** `[sniper-devops] Implementar Bloqueios Automáticos via Parâmetros`
**Priority:** Medium
**Status:** Backlog

**Description:**

```
Criar sistema de configuração de regras de bloqueio automático baseado em parâmetros pré-estabelecidos.

## Regras Suportadas

1. **Rate Limit**: Bloquear após X requisições em Y tempo
2. **HTTP Status**: Bloquear por status 403, 429, 500, etc
3. **Attack Pattern**: Bloquear por padrão (SQL injection, LFI, etc)
4. **Geolocalização**: Bloquear por país (opcional)

## Configuração

Arquivo: conf/autoblock.conf

RULE_RATE_LIMIT="1"
RATE_LIMIT_THRESHOLD="100"
RATE_LIMIT_WINDOW="1m"
RATE_LIMIT_BLOCK="1"

RULE_HTTP_STATUS="1"
HTTP_STATUS_BLOCK="403,429,500"
HTTP_STATUS_COUNT="5"

RULE_ATTACK_PATTERN="1"
ATTACK_PATTERNS="union select|exec\(|drop table"

## Comandos

./sniper autoblock list      # Listar regras ativas
./sniper autoblock test <IP> # Testar se IP deveria ser bloqueado

## Integração

Integrar com tail module para aplicar regras automaticamente
```

**Acceptance Criteria:**

```
- [ ] Arquivo conf/autoblock.conf com regras
- [ ] Função load_autoblock_rules()
- [ ] Função evaluate_autoblock_rule()
- [ ] Comando ./sniper autoblock list
- [ ] Comando ./sniper autoblock test <IP>
- [ ] Integração com tail
- [ ] Testes de homologação
```

**Labels:** enhancement, autoblock

**Story Points:** 8

---

### Story 4: Integração com LogCenter e LLM

**Type:** Story
**Project:** [Seu projeto]
**Summary:** `[sniper-devops] Integração com LogCenter e LLM`
**Priority:** Medium
**Status:** Backlog

**Description:**

```
Integrar sistema com LogCenter para receber análises de LLM e fazer bloqueios automáticos.

## Fluxo

LogCenter API → LLM Analysis → Resultado JSON → Bloqueio automático

## Resposta Esperada

{
  "status": "success",
  "ips": ["1.2.3.4", "5.6.7.8"],
  "reason": "exploit_attempt"
}

## Implementação

1. Função fetch_from_logcenter() - Consulta API
2. Parser de resposta JSON
3. Validação de IPs
4. Log com source="logcenter_llm"
5. Retry em caso de falha
6. Modo daemon/cron

## Comandos

./sniper fw --from-logcenter        # Bloqueio único
./sniper daemon --from-logcenter    # Monitor contínuo (cron)

## Configuração

LOGCENTER_ENABLED="1"
LOGCENTER_URL="https://logcenter/api/malicious-ips"
LOGCENTER_API_KEY="seu_token"
LOGCENTER_POLL_INTERVAL="30s"
```

**Acceptance Criteria:**

```
- [ ] Função fetch_from_logcenter()
- [ ] Parser de JSON
- [ ] Validação de IPs
- [ ] Log com origem
- [ ] Retry automático
- [ ] Modo daemon
- [ ] Testes com mock API
```

**Labels:** enhancement, integration, logcenter

**Story Points:** 5

---

## 📝 Opção 2: Bulk Import (se Jira suporta)

Alguns Jira/ferramentas permitem import via CSV ou JSON. Se sua instância suportar, você pode exportar essas histórias em formato compatível.

---

## 🔄 Opção 3: Via Jira API (Programático)

```bash
# Se tiver acesso à API do Jira
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d @story.json \
  https://seu-jira.atlassian.net/rest/api/3/issues
```

---

## 📋 Campos Importantes no Jira

Quando criar cada história, preencha:

| Campo | Valor |
|-------|-------|
| **Project** | [Seu projeto] |
| **Issue Type** | Story |
| **Summary** | [sniper-devops] [Descrição] |
| **Description** | [Copiar da seção acima] |
| **Priority** | High/Medium/Low |
| **Status** | Done/Backlog |
| **Labels** | documentation, enhancement, feature |
| **Story Points** | 3, 5, 8, 13 |
| **Assignee** | [Você] |
| **Due Date** | [Data] |
| **Link** | Repository: https://github.com/AlexVUH/sniper-devops |

---

## ✅ Checklist Pós-Criação

- [ ] Story 1 criada e marcada como "Done"
- [ ] Story 2 criada como "Backlog"
- [ ] Story 3 criada como "Backlog"
- [ ] Story 4 criada como "Backlog"
- [ ] Todas linkadas ao Epic
- [ ] Labels e story points preenchidos
- [ ] Documentação linke no GitHub
- [ ] Aviso ao time sobre o roadmap

---

## 💡 Dicas

1. **Criar um Epic primeiro:**
   - Title: "Desenvolvimento sniper-devops"
   - Link as 4 stories ao Epic

2. **Usar labels consistentes:**
   - `sniper-devops`: projeto
   - `documentation`: relacionado a docs
   - `feature`: nova funcionalidade
   - `enhancement`: melhoria
   - `tail-module`: específico do módulo tail

3. **Story Points sugeridos:**
   - Story 1 (Docs): 3 pontos ✅ (já feito)
   - Story 2 (Tail): 13 pontos (complexo)
   - Story 3 (Autoblock): 8 pontos (médio)
   - Story 4 (LogCenter): 5 pontos (integração)

4. **Subtasks úteis para cada story:**
   - Research/Design
   - Development
   - Testing
   - Documentation
   - Code Review

---

## 🎯 Próximos Passos

1. ✅ Criar as 4 histórias no Jira
2. ⏳ Começar com Story 2 (Tail module)
3. ⏳ Implementar e testar
4. ⏳ Fazer PR no GitHub
5. ⏳ Merge e release

