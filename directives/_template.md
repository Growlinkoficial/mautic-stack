---
priority: medium
domain: template
dependencies: []
conflicts_with: []
last_updated: 2026-02-19
---

# Directive: [Nome da Operação]

## Objetivo
<!-- O que esta directive faz e por que existe -->

## Inputs Necessários
| Input | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `param1` | string | Sim | Descrição do parâmetro |
| `param2` | int | Não | Descrição do parâmetro |

## Outputs Esperados
<!-- O que é produzido ao final da execução -->
- **Entregável principal**: [Google Sheet / arquivo / etc.]
- **Logs**: `.tmp/logs/execution_YYYYMMDD.jsonl`

## Scripts de Execução
```bash
# Ordem de execução
python execution/exemplo.py --input "valor"
```

## Critérios de Sucesso
- [ ] Condição 1
- [ ] Condição 2

## Edge Cases Conhecidos
- **Caso X**: Como tratar
- **Caso Y**: Como tratar

## Tempo Estimado de Execução
~X minutos

---

## Learnings

<!-- Append learnings abaixo conforme o sistema aprende -->

<!-- 
**[YYYY-MM-DD] - Learning: [Título Breve]**
- **Context**: O que revelou isso
- **Issue**: O que deu errado / foi descoberto
- **Solution**: Como foi resolvido
- **Impact**: O que mudou no processo
-->
