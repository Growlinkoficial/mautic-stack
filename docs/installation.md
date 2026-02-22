# Guia de Instalação — `install.sh`

## Por que esse script existe

Implantar o Mautic 5 com Docker manualmente envolve ~11 passos: verificar pré-requisitos, instalar Docker, gerar senhas, criar `.env`, gerar `local.php`, baixar imagens, construir imagem customizada, aguardar race conditions de boot, executar o instalador CLI, configurar Nginx/SSL e configurar o container de cron dedicado. Um erro em qualquer etapa deixa o stack em estado indeterminado.

O `install.sh` é um **orquestrador idempotente**: pode ser rodado múltiplas vezes sem quebrar o que já funciona.

---

## Padrões de Resiliência Aplicados

| Padrão | Implementação |
|--------|---------------|
| **Fail-fast** | `set -euo pipefail` — aborta ao primeiro erro |
| **Higiene CRLF** | Auto-corrige finais de linha Windows antes de executar |
| **Trap cleanup** | `trap cleanup EXIT` — loga o estágio onde houve falha |
| **PROJECT_ROOT absoluto** | `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` — funciona de qualquer diretório |
| **Idempotência** | Verifica se `.env`, `local.php`, containers e instalação já existem antes de agir |
| **Anti-corrupção `envsubst`** | Lista explícita de variáveis evita que `$parameters` do PHP seja apagado |
| **Race condition guard** | Aguarda `/var/www/html/bin/console` existir antes de qualquer CLI |
| **Sanity check** | Verifica se `$parameters` ainda está no `local.php` após geração |

---

## Pré-requisitos

- Ubuntu 24.04 LTS
- Mínimo 2 GB RAM, 20 GB disco
- Acesso root (`sudo`)
- Docker (instalado automaticamente pelo script via `scripts/docker_install.sh`)
- Porta `8080` livre (configurável no wizard)

Verificações automáticas feitas por `scripts/preflight.sh`:
- RAM disponível
- Espaço em disco
- Conectividade com internet

---

## O Wizard Interativo

Na primeira execução, o script cria o `.env` interativamente:

```
[1/3] DOMÍNIO
  → s = domínio próprio (ativa Nginx + SSL automático via Certbot)
  → n = localhost (sem Nginx, acesso direto via porta)

[2/3] PORTA
  → Padrão: 8080

[3/3] ADMINISTRADOR
  → Email e nome do admin inicial
  → Senhas geradas automaticamente com openssl rand
```

> ⚠️ **As senhas são geradas e salvas no `.env`** e nunca exibidas no terminal após instalação. Guarde o arquivo `.env` em local seguro.

---

## Fluxo de Execução (11 Etapas)

```
1.  Wizard         → Cria .env se não existir
2.  Validação root → Garante sudo
3.  Pre-flight     → RAM, disco, conectividade
4.  Docker Install → Instalação via docker_install.sh (idempotente)
5.  Idempotência   → Verifica se stack já está rodando (re/atualiza ou sai)
6.  Config         → Gera config/local.php a partir de local.php.tpl via envsubst
7.  Pull + Build   → Baixa imagens base + constrói mautic-custom:5-apache (Dockerfile)
8.  Docker Up      → Sobe os 5 containers com healthcheck wait
9.  File Init      → Aguarda bin/console estar disponível no volume (evita race condition)
10. Mautic Install → Executa mautic:install via CLI (headless) + marca installed=true
11. Pós-install    → cache:clear, assets, logrotate, Nginx/SSL (se domínio)
```

---

## Executando

```bash
# Primeira instalação
chmod +x install.sh
sudo ./install.sh

# Re-execução (atualizar ou verificar)
sudo ./install.sh
# → Pergunta: [r]einiciar, [a]tualizar ou [s]air
```

---

## Artifacts Gerados

| Artifact | Local | Descrição |
|----------|-------|-----------|
| `.env` | raiz do projeto | Credenciais e configuração |
| `config/local.php` | raiz do projeto | Configuração PHP do Mautic |
| `/etc/logrotate.d/mautic-stack` | sistema | Rotação de logs do host |
| `/var/log/mautic-stack/install_verbose.log` | sistema | Log completo da instalação |

---

## Relacionado

- **Reverter completamente**: [`uninstall.sh`](../uninstall.sh) — simétrico ao install
- **Verificar saúde**: [`scripts/validate.sh`](../scripts/validate.sh)
- **Operações do dia a dia**: [`docs/operations.md`](operations.md)
- **Erros conhecidos**: [`docs/troubleshooting.md`](troubleshooting.md)
