# 📊 Resumo das Histórias de Jira - sniper-devops

## 📈 Visão Geral

```
┌─────────────────────────────────────────────────────────────────┐
│  EPIC: Desenvolvimento sniper-devops                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Story 1: Documentar Arquitetura e Módulos ✅ DONE              │
│  ├─ Priority: High                                              │
│  ├─ Status: Done                                                │
│  ├─ Story Points: 3                                             │
│  └─ Deliverables: README.md, Diagrama fluxo, Funções            │
│                                                                  │
│  Story 2: Módulo Tail (Monitoramento) ⏳ BACKLOG                │
│  ├─ Priority: High                                              │
│  ├─ Status: To Do                                               │
│  ├─ Story Points: 13                                            │
│  └─ Deliverables: tail.sh, parsers, filtros                     │
│                                                                  │
│  Story 3: Bloqueios Automáticos ⏳ BACKLOG                      │
│  ├─ Priority: Medium                                            │
│  ├─ Status: To Do                                               │
│  ├─ Story Points: 8                                             │
│  └─ Deliverables: autoblock.conf, regras, CLI                   │
│                                                                  │
│  Story 4: Integração LogCenter/LLM ⏳ BACKLOG                   │
│  ├─ Priority: Medium                                            │
│  ├─ Status: To Do                                               │
│  ├─ Story Points: 5                                             │
│  └─ Deliverables: API client, daemon, testes                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Story 1: Documentar Arquitetura e Módulos Existentes

### ✅ Status: COMPLETO

**Objective:** Documentar completamente a arquitetura, módulos existentes, funções e fluxo do sistema sniper-devops.

**Entregáveis:**
- ✅ README.md (900+ linhas) 
- ✅ Documentação técnica de 14+ funções
- ✅ 4 diagramas de fluxo ASCII
- ✅ Exemplos de uso
- ✅ Troubleshooting
- ✅ Commit no GitHub

**Componentes Documentados:**
```
sniper.sh (CLI)
  ├─ lib/core.sh (debug, lock, colors)
  ├─ lib/validate.sh (IP/CIDR, whitelist)
  ├─ lib/log.sh (TXT, JSON)
  ├─ lib/utils.sh (ipset, iptables)
  ├─ fw/fw.sh (dispatcher)
  ├─ fw/blacklist.sh (operações: add/del/check/list/flush)
  ├─ conf/sniper.conf (config)
  └─ conf/whitelist.json (redes bloqueadas)
```

**Testes:** 39 total | 35 PASS | 4 FAIL (esperado)

---

## 📋 Story 2: Implementar Módulo "tail" para Monitoramento de Logs

### ⏳ Status: BACKLOG (Próximo)

**Objective:** Implementar módulo de monitoramento de logs para detectar IPs suspeitos e criar bloqueios automáticos.

**Comandos Esperados:**
```bash
./sniper tail list                                           # Listar
./sniper tail /var/log/apache2/access.log                   # Monitor
./sniper tail 192.168.1.100                                 # Rastrear
./sniper tail /var/log/apache2/access.log --status 4xx --autoblock  # Filtros
```

**Sub-tasks:**

| # | Tarefa | Descrição |
|---|--------|-----------|
| 2.1 | Parser de Logs | `detectors/log_format.sh` - Detectar Apache/Nginx/OpenResty |
| 2.2 | Filtros Comuns | `tail/common.sh` - Status, padrão, threshold |
| 2.3 | Comando Tail | `tail/tail.sh` - Dispatcher e monitor |
| 2.4 | Bloqueio Automático | Aplicar regras e --autoblock |
| 2.5 | Testes | 15+ testes de homologação |

**Arquivos a Criar/Modificar:**
```
Criar:
  ├─ tail/tail.sh (novo)
  ├─ conf/tail.conf (novo)
  └─ scripts/tail-test.sh (novo)

Modificar:
  ├─ detectors/log_format.sh
  ├─ tail/common.sh
  ├─ tail/apache.awk
  ├─ tail/openresty.awk
  └─ sniper.sh
```

**Saída Esperada:**
```
[TAIL][14:32:05] Monitorando: /var/log/apache2/access.log
[TAIL][14:32:05] Filtros: status=403, threshold=5/1m, autoblock=sim

192.168.1.100 | 5 requisições 403 em 1m | BLOQUEADO ✅
192.168.1.101 | 3 requisições 403 em 1m | OK

[TAIL][14:32:10] Total bloqueados: 2
[TAIL][14:32:10] Logs em: /export/logs/sniper-tail.json
```

---

## 📋 Story 3: Implementar Bloqueios Automáticos via Parâmetros

### ⏳ Status: BACKLOG

**Objective:** Criar sistema de configuração de regras de bloqueio automático baseado em parâmetros pré-estabelecidos.

**Regras Suportadas:**

| Regra | Configuração | Exemplo |
|-------|--------------|---------|
| **Rate Limit** | Threshold + Window | 100 req/min → Bloquear |
| **HTTP Status** | Status + Count | 5x 403 → Bloquear |
| **Attack Pattern** | Regex | "union select" → Bloquear |
| **Geolocalização** | Países | CN, KP → Bloquear (opcional) |

**Arquivo de Configuração:**
```bash
# conf/autoblock.conf

RULE_RATE_LIMIT="1"
RATE_LIMIT_THRESHOLD="100"
RATE_LIMIT_WINDOW="1m"

RULE_HTTP_STATUS="1"
HTTP_STATUS_BLOCK="403,429,500"
HTTP_STATUS_COUNT="5"

RULE_ATTACK_PATTERN="1"
ATTACK_PATTERNS="union select|exec\(|drop table"
```

**Comandos:**
```bash
./sniper autoblock list      # Listar regras ativas
./sniper autoblock test <IP> # Testar aplicação de regras
```

**Integração:**
```
tail/tail.sh → Lê logs
     ↓
lib/autoblock.sh → Avalia regras
     ↓
fw/blacklist.sh → Faz bloqueio automático
     ↓
Logs com source="auto"
```

---

## 📋 Story 4: Integração com LogCenter e LLM

### ⏳ Status: BACKLOG

**Objective:** Integrar sistema com LogCenter para receber análises de LLM e fazer bloqueios automáticos.

**Fluxo:**
```
┌────────────────────────────────────────────────┐
│ LogCenter API                                  │
│ (Análise de tráfego/logs)                      │
└────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────┐
│ LLM Analysis                                    │
│ (Detecta padrões suspeitos)                     │
└────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────┐
│ Resultado JSON                                  │
│ {                                              │
│   "ips": ["1.2.3.4", "5.6.7.8"],              │
│   "reason": "exploit_attempt"                  │
│ }                                              │
└────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────┐
│ sniper-devops                                   │
│ Bloqueio automático com source=logcenter_llm   │
└────────────────────────────────────────────────┘
```

**Configuração:**
```bash
# conf/logcenter.conf

LOGCENTER_ENABLED="1"
LOGCENTER_URL="https://logcenter/api/malicious-ips"
LOGCENTER_API_KEY="seu_token"
LOGCENTER_POLL_INTERVAL="30s"
LOGCENTER_RETRY="3"
```

**Comandos:**
```bash
./sniper fw --from-logcenter          # Bloqueio único
./sniper daemon --from-logcenter      # Monitor contínuo (cron)
```

**Arquivo de Implementação:**
```
Criar:
  └─ lib/logcenter.sh
    ├─ fetch_from_logcenter()
    ├─ parse_logcenter_response()
    └─ block_from_logcenter()
```

**Log Estruturado:**
```json
{
  "datetime": "2026-01-26T14:32:05Z",
  "action": "add",
  "ip": "1.2.3.4",
  "source": "logcenter_llm",
  "user": "daemon",
  "logcenter_reason": "exploit_attempt"
}
```

---

## 📊 Roadmap Visual

```
Phase 1: Documentação
═══════════════════════════════════════════════════════════════════
[████████████████████████████████████████████████] 100% ✅ DONE

Phase 2: Módulo Tail  
═══════════════════════════════════════════════════════════════════
[░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0% ⏳ NEXT
  └─ 2.1: Parser      [░░░░░░░░░░░░░] Planejado
  └─ 2.2: Filtros     [░░░░░░░░░░░░░] Planejado
  └─ 2.3: Tail.sh     [░░░░░░░░░░░░░] Planejado
  └─ 2.4: Autoblock   [░░░░░░░░░░░░░] Planejado
  └─ 2.5: Testes      [░░░░░░░░░░░░░] Planejado

Phase 3: Autoblock Rules
═══════════════════════════════════════════════════════════════════
[░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0% ⏳ BACKLOG

Phase 4: LogCenter Integration
═══════════════════════════════════════════════════════════════════
[░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0% ⏳ BACKLOG
```

---

## 🎯 Métricas

| Métrica | Story 1 | Story 2 | Story 3 | Story 4 | Total |
|---------|---------|---------|---------|---------|-------|
| Story Points | 3 | 13 | 8 | 5 | **29** |
| Status | ✅ Done | ⏳ To Do | ⏳ To Do | ⏳ To Do | 3% |
| Testes | 39 | ~15 | ~10 | ~5 | ~69 |
| Funções | 14+ | 8+ | 4+ | 3+ | 29+ |
| Arquivos | 9 | +3 | +2 | +1 | +6 |

---

## 💾 Arquivos Criados

```
sniper-devops/
├─ JIRA_STORY.md          ← Histórias em detalhe
├─ JIRA_IMPORT_GUIDE.md   ← Guia de importação
├─ README.md              ← Documentação técnica (UPDATED)
├─ .github/
│  └─ workflows/
│     └─ ci.yml          ← (Futuro: CI/CD)
└─ ...
```

---

## 🚀 Próximos Passos

### Imediato (Hoje)
1. ✅ Criar JIRA_STORY.md
2. ✅ Criar JIRA_IMPORT_GUIDE.md
3. ⏳ Importar histórias para Jira
4. ⏳ Atribuir Story 2 (Tail)

### Curto Prazo (1-2 semanas)
1. ⏳ Implementar Story 2 (Tail)
   - Parser de logs
   - Filtros
   - Monitor em tempo real
   
2. ⏳ Testes de homologação
   - 15+ testes automáticos
   - Teste manual

3. ⏳ Fazer PR e merge

### Médio Prazo (3-4 semanas)
1. ⏳ Implementar Story 3 (Autoblock)
2. ⏳ Integrar com Story 2

### Longo Prazo (5+ semanas)
1. ⏳ Implementar Story 4 (LogCenter)
2. ⏳ Testes com SIEM real
3. ⏳ Release

---

## 📞 Contato/Suporte

- **Repository**: https://github.com/AlexVUH/sniper-devops
- **Issues**: https://github.com/AlexVUH/sniper-devops/issues
- **Documentation**: README.md, JIRA_STORY.md

---

## ✅ Checklist Final

- [x] Story 1: Documentar (✅ DONE)
- [x] Criar JIRA_STORY.md
- [x] Criar JIRA_IMPORT_GUIDE.md
- [x] Fazer commit no GitHub
- [ ] Importar para Jira
- [ ] Comunicar ao time
- [ ] Começar Sprint com Story 2

---

**Gerado em:** 2026-01-26
**Versão:** 1.0
**Autor:** AI Assistant

