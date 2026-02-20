# Mautic Stack (v5 + Redis + MySQL + Docker)

Script de instalação **automatizado, idempotente e resiliente** para Mautic 5 no Ubuntu 24.04.
Stack: `mautic/mautic:5-apache` · `mysql:8.0` · `redis:7-alpine` · Nginx + SSL (opcional).

---

## 🚀 Instalação

```bash
chmod +x install.sh
sudo ./install.sh
```

O instalador guia você por todas as configurações necessárias via **wizard interativo**:
- Domínio ou localhost
- Porta (padrão 8080)
- Email e nome do administrador
- **Senhas geradas automaticamente** e salvas no `.env`

> Referência de variáveis disponíveis: `.env.example`

---

## 📂 Estrutura

| Arquivo/Diretório | Descrição |
|---|---|
| `install.sh` | Instalador principal (idempotente) |
| `uninstall.sh` | Remoção completa (containers, crons, SSL) |
| `backup.sh` | Backup do banco MySQL + volume de arquivos |
| `restore.sh` | Restauração a partir de backup existente |
| `docker-compose.yml` | Definição dos 4 serviços (com healthchecks e resource limits) |
| `config/` | Templates de configuração (`local.php.tpl`, `php.ini`) |
| `scripts/` | Libs e scripts auxiliares (`preflight`, `nginx_setup`, `validate`) |
| `directives/` | SOPs operacionais (guia para agentes de IA) |
| `backups/` | Saída padrão de backups locais |
| `.learnings/` | Registro de erros e aprendizados operacionais |

---

## 🛠️ Comandos Úteis

```bash
# Status do stack
sudo ./scripts/validate.sh

# Backup manual
sudo ./backup.sh

# Restauração
sudo ./restore.sh

# Logs em tempo real
docker compose logs -f mautic
docker compose logs -f mautic_worker

# Limpar cache do Mautic
docker compose exec mautic php bin/console cache:clear

# Reiniciar apenas um serviço
docker compose restart mautic
```

---

## ⚙️ Pré-requisitos

- Ubuntu 24.04 LTS  
- Mínimo 2GB RAM, 20GB disco  
- Acesso root (sudo)  
- Docker instalado (ou o instalador instala automaticamente)

---

## 🔒 Segurança

- Todos os segredos via `.env` (nunca commitar)  
- Redis com senha obrigatória (`REDIS_PASSWORD`)  
- Senhas admin **nunca exibidas** no terminal após instalação  
- Logrotate configurado (14 dias, compactado)

---

## ⚖️ Licença
Uso interno Growlink.
