---
priority: high
domain: infra
dependencies: [docker, nginx, mautic]
conflicts_with: []
last_updated: 2026-02-20
# Atualizado: Fix permissões cache (ERR-014), libavif/gd (ERR-015), healthcheck 301 (ERR-016)
---

# Directive: Mautic Stack Management

## Goal
Automate the deployment, maintenance, backup, and restore of a Mautic 5 instance with Redis caching on Ubuntu 24.04.
**Image**: Custom build via `Dockerfile` based on `mautic/mautic:5-apache` (adds `libavif15` to fix `gd` extension — ERR-20260220-015).
**Do not hardcode patch versions** — check Docker Hub tags first (LRN-20260220-003).

## Inputs
- `.env` file with database and admin credentials (copy from `.env.example`).
- Ubuntu 24.04 server with min 2GB RAM.

## Core Scripts
1. `install.sh` — Main automated installer (idempotent, uses `set -euo pipefail`).
2. `Dockerfile` — Custom image: installs `libavif15` to fix `gd` PHP extension (ERR-20260220-015).
3. `uninstall.sh` — Complete stack removal (containers, crons, logrotate, SSL cert).
4. `backup.sh` — Daily backup of MySQL DB + mautic_data volume (requires `PROJECT_ROOT`).
5. `restore.sh` — Restores MySQL + volume from latest backup in `backups/`.
6. `scripts/validate.sh` — Full health check (containers, HTTP, MySQL, Redis, worker).

## Success Criteria
- [ ] 4 containers running: `mautic`, `mautic_worker`, `mysql`, `redis`
- [ ] Mautic accessible via URL (HTTP 200 on `/s/login`)
- [ ] Redis cache adapter active (`debug:config mautic_cache | grep redis`)
- [ ] Cron jobs active: `/etc/cron.d/mautic-stack`
- [ ] Logrotate configured: `/etc/logrotate.d/mautic-stack`
- [ ] Worker consuming queue (visible in `validate.sh`)

## Operational Procedures

### Installation
```bash
cp .env.example .env && nano .env
sudo ./install.sh
```

### Backup
```bash
sudo ./backup.sh
# Output: backups/mysql_backup_YYYYMMDD_HHMMSS.sql
#         backups/mautic_files_YYYYMMDD_HHMMSS.tar.gz
```

### Restore
```bash
sudo ./restore.sh
# Selects latest backup automatically. Stops mautic/worker, restores, restarts.
```

### Uninstall
```bash
sudo ./uninstall.sh
# Removes: containers, volumes (optional), crons, logrotate, Nginx config, SSL cert, logs (optional)
```

### Troubleshooting
1. **Container Logs**: `docker compose logs -f [service]`
2. **Cron Logs**: `cat /var/log/mautic-stack/cron.log`
3. **Mautic App Logs**: `docker compose exec mautic tail -f var/logs/mautic_prod.log`
4. **Full Health Check**: `sudo ./scripts/validate.sh`

## Edge Cases
- **Memory Issues**: Server needs > 1.5GB RAM. Worker has `--memory-limit=256M` (unit required — see LRN-20260219-001).
- **Port Conflicts**: Change `MAUTIC_PORT` in `.env` if 8080 is occupied.
- **DNS for SSL**: Domain must point to server IP before Nginx+SSL setup.
- **Volume :ro on Worker**: `mautic_data` is mounted read-only on `mautic_worker` — deliberate. Worker must not write assets (WARN-006).

## Known Gotchas
- Bash library source guards must use `"true"` not `1` (LRN-20260220-001 / CRIT-002).
- All scripts use `PROJECT_ROOT` derived from `BASH_SOURCE[0]` — never rely on `pwd` (LRN-20260220-002).
- Redis healthcheck requires `REDIS_PASSWORD` in the `environment` block (LRN-20260220-004 / ERR-20260220-006).
- `mautic/mautic:5.2.6` tag doesn't exist — use `5-apache` or `v5` (LRN-20260220-003).
- **[LRN-20260220-008] Mautic 5 + Docker + Nginx SSL: 5 gotchas obrigatórios**
  1. Container env: usar `MAUTIC_DB_*` (não `MYSQL_*`) + `DOCKER_MAUTIC_ROLE` em ambos mautic e mautic_worker.
  2. Race condition: aguardar `/var/www/html/bin/console` existir antes de qualquer CLI (`until test -f ...`).
  3. Workdir: sempre `-w /var/www/html` em todos os `docker compose exec`.
  4. CLI params: `mautic:install` usa underscores (`--db_host`), não hyphens (`--db-host`).
  5. **[NOVO] Proxy SSL**: `local.php` requer `trusted_proxies` AND Apache requer `SetEnvIf X-Forwarded-Proto https HTTPS=on` (via volume mount de `apache-proxy.conf`).
- **[LRN-20260220-009] Envsubst guard**: Sempre use lista explícita de variáveis (ex: `envsubst '${VAR1}${VAR2}'`) ao gerar `local.php` para evitar que variáveis PHP legítimas sejam apagadas.
- **[ERR-20260220-014] Permissões cache/idioma**: Após instalação, executar `chmod -R 775 /var/www/html/var/cache` e `var/logs`. Sem isso, troca de idioma (`pt_BR`) falha com `Permission denied` no `LanguageHelper.php`.
- **[ERR-20260220-015] libavif/gd**: A imagem `mautic/mautic:5-apache` requer `libavif15` que não está no Debian base. Usar o `Dockerfile` customizado do projeto. Para aplicar: `docker compose build && docker compose up -d --force-recreate mautic mautic_worker`.
- **[ERR-20260220-016] Healthcheck 301**: O curl interno do healthcheck deve usar `-L --max-redirs 3` para não falhar em instalações SSL onde `/s/login` retorna 301.

---

## Learnings Log

**[2026-02-19] - Learning: Race Conditions**
- **Context**: `docker compose up` with missing config file.
- **Issue**: Docker creates a directory if `local.php` file is missing (instead of failing cleanly).
- **Solution**: Added validation guard in `install.sh` to ensure `local.php` exists before `up`.
- **Impact**: Installation is now atomic — aborts explicitly if config is missing.

**[2026-02-20] - Learning: Patch v1.2 Bulk Fixes**
- **Context**: Tech review and install debugging session.
- **Issues**: readonly variable conflicts, wrong Docker tags, Redis healthcheck auth, missing `PROJECT_ROOT`, no resource limits, no logrotate.
- **Solution**: See ERRORS.md / LEARNINGS.md in `.learnings/` for full structured log.
- **Impact**: 7 files changed, all issues resolved, `restore.sh` created for disaster recovery.
**[2026-02-20] - Learning: official MAUTIC_TRUSTED_PROXIES format**
- **Context**: Symfony 5.4 behind Docker proxy.
- **Issue**: Standard `TRUSTED_PROXIES` env was ignored.
- **Solution**: Use `MAUTIC_TRUSTED_PROXIES` with JSON array format: `'["0.0.0.0/0"]'`.
- **Impact**: Correct protocol detection at the framework level.

**2026-02-20 - Learning: Apache HTTPS Detection Safeguard**
- **Context**: `ERR_TOO_MANY_REDIRECTS` on Mautic 5.
- **Issue**: Application layers sometimes miss proxy headers.
- **Solution**: Mount `config/apache-proxy.conf` to `/etc/apache2/conf-enabled/` with `SetEnvIf`.
- **Impact**: Force PHP to see `HTTPS=on`, breaking all redirect loops.

**[2026-02-20] - Learning: Permission denied on language pack download**
- **Context**: User tried to change UI language to `pt_BR` via `/s/account`.
- **Issue**: `file_put_contents(var/cache/prod/pt_BR.zip): Permission denied` — `www-data` lacked write access to `var/cache`.
- **Solution**: Added `chmod -R 775 var/cache var/logs` to `install.sh` post-install step.
- **Impact**: Language packs now download successfully after installation.

**[2026-02-20] - Learning: libavif15 missing — gd extension fails to load**
- **Context**: PHP startup warning on every CLI and web request.
- **Issue**: `mautic/mautic:5-apache` compiled `gd` with AVIF support but Debian Bookworm lacks `libavif15`.
- **Solution**: Created `Dockerfile` extending the base image with `apt-get install libavif15`. Updated `docker-compose.yml` to use `build:` instead of direct `image:`.
- **Impact**: Extension `gd` now loads correctly; image, thumbnail, and captcha generation functional.
