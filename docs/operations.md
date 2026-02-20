# Operações do Dia a Dia

> Todos os comandos devem ser executados dentro do diretório do projeto:
> ```bash
> cd /home/mautic-stack
> ```

---

## Verificação de Saúde

```bash
# Verificação completa: containers, HTTP, MySQL, Redis, worker
sudo ./scripts/validate.sh

# Status rápido dos containers
docker compose ps

# Logs em tempo real
docker compose logs -f mautic
docker compose logs -f mautic_worker
```

---

## Cache

```bash
# Limpar cache (obrigatório após trocar idioma ou atualizar configs)
docker compose exec -w /var/www/html mautic php bin/console cache:clear

# Warmup (opcional, pré-aquece o cache após limpeza)
docker compose exec -w /var/www/html mautic php bin/console cache:warmup
```

---

## 🌐 Trocando o Idioma da Interface

O idioma é configurado **por usuário** (não globalmente) e requer 3 passos:

**1 — Alterar no perfil**
- Menu do avatar (canto superior direito) → **Account Settings** → `/s/account`
- Campo **"Language"** → Selecione `pt_BR - Portuguese Brazil` → **Save**

**2 — Limpar o cache** (obrigatório)
```bash
docker compose exec -w /var/www/html mautic php bin/console cache:clear
```

**3 — Fazer logout e login novamente**

> ⚠️ A interface não atualiza sem logout. O Mautic aplica o idioma apenas em novas sessões.

---

## Restart e Rebuild

```bash
# Reiniciar um serviço específico
docker compose restart mautic
docker compose restart mautic_worker

# Recriar container (força releitura de variáveis de ambiente)
docker compose up -d --force-recreate mautic

# Reconstruir imagem customizada (após atualizar o Dockerfile)
docker compose build
docker compose up -d --force-recreate mautic mautic_worker
```

---

## Banco de Dados (MySQL)

```bash
# Acessar o MySQL interativamente
docker compose exec mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" mautic

# Verificar conexão
docker compose exec mysql mysqladmin ping -u root -p"${MYSQL_ROOT_PASSWORD}" --silent
```

---

## Filas e Worker (Symfony Messenger)

```bash
# Ver se o worker está consumindo filas
docker compose ps mautic_worker

# Logs do worker (útil para debug de envio de e-mails)
docker compose logs -f mautic_worker

# Dispatchar manualmente campanhas e segmentos
docker compose exec -w /var/www/html mautic php bin/console mautic:campaigns:trigger
docker compose exec -w /var/www/html mautic php bin/console mautic:segments:update
docker compose exec -w /var/www/html mautic php bin/console mautic:emails:send
```

---

## Assets e Plugins

```bash
# Regenerar assets compilados (CSS/JS)
docker compose exec -w /var/www/html mautic php bin/console mautic:assets:generate

# Listar e atualizar plugins
docker compose exec -w /var/www/html mautic php bin/console mautic:plugins:reload
```

---

## Corrigir Permissões

Necessário após reinicializações que causem `Permission denied` (ex: troca de idioma):

```bash
docker compose exec mautic chown -R www-data:www-data /var/www/html
docker compose exec mautic chmod -R 775 /var/www/html/var/cache
docker compose exec mautic chmod -R 775 /var/www/html/var/logs
```

---

## Logs do Sistema

```bash
# Log de instalação
cat /var/log/mautic-stack/install_verbose.log

# Log de cron jobs
tail -f /var/log/mautic-stack/cron.log

# Log de aplicação do Mautic
docker compose exec mautic tail -f var/logs/mautic_prod.log
```

---

## Relacionado

- **Backup e restauração**: [`docs/backup-restore.md`](backup-restore.md)
- **Erros comuns**: [`docs/troubleshooting.md`](troubleshooting.md)
