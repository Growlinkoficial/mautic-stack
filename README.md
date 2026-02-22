# Mautic Stack (v5 + Redis + MySQL + Docker)

Instalação **automatizada, idempotente e resiliente** do Mautic 5 no Ubuntu 24.04.

```
mautic/mautic:5-apache (custom)  ·  mysql:8.0  ·  redis:7-alpine  ·  Nginx + SSL
```

---

## ⚡ Instalação Rápida

```bash
chmod +x install.sh
sudo ./install.sh
```

O wizard interativo configura domínio, porta, admin e gera senhas automaticamente.
Credenciais salvas em `.env` — nunca exibidas no terminal.

> Referência de variáveis: `.env.example`

---

## 📚 Documentação

| Tópico | Descrição |
|--------|-----------|
| [📦 Instalação](docs/installation.md) | Como o `install.sh` funciona, pré-requisitos, wizard, fluxo de 11 etapas |
| [💾 Backup & Restore](docs/backup-restore.md) | O que é salvo, como restaurar, estratégia de retenção |
| [🛠️ Operações](docs/operations.md) | Comandos do dia a dia, idioma, cache, logs, worker |
| [🔎 Troubleshooting](docs/troubleshooting.md) | Todos os erros conhecidos — sintoma → causa → solução |
| [🏗️ Arquitetura](docs/architecture.md) | Por que 5 containers, SSL termination, Dockerfile customizado |

---

## 📂 Estrutura do Projeto

```
.
├── install.sh            # Orquestrador principal (idempotente)
├── uninstall.sh          # Remove tudo que o install criou
├── backup.sh             # Dump MySQL + tarball do volume
├── restore.sh            # Restaura a partir do backup mais recente
├── Dockerfile            # Imagem customizada (adiciona libavif15 para gd)
├── docker-compose.yml    # 5 serviços com healthchecks e resource limits
├── config/               # local.php.tpl, php.ini, apache-proxy.conf
├── scripts/              # preflight, docker_install, nginx_setup, validate
├── docs/                 # Documentação técnica detalhada
├── directives/           # SOPs operacionais (guia para agentes de IA)
├── backups/              # Saída dos backups locais
└── .learnings/           # Registro histórico de erros e aprendizados
```

---

## ⚙️ Pré-requisitos

- Ubuntu 24.04 LTS · Mín. 2 GB RAM · 20 GB disco · Acesso root

---

## 🔒 Segurança

- Todos os segredos em `.env` (nunca commitar)
- Redis com senha obrigatória
- Logrotate configurado (14 dias, compactado)

---

## ⚖️ Licença

Uso interno Growlink.
