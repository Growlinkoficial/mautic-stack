---
priority: high
domain: infra
dependencies: [docker, nginx, mautic]
conflicts_with: []
last_updated: 2026-02-20
---

# Directive: Mautic Stack Management

## Goal
Automate the deployment, maintenance, backup, and restore of a Mautic 5 instance with Redis caching on Ubuntu 24.04.
Image: `mautic/mautic:5-apache`. **Do not hardcode patch versions** — check Docker Hub tags first (LRN-20260220-003).

## Inputs
- `.env` file with database and admin credentials (copy from `.env.example`).
- Ubuntu 24.04 server with min 2GB RAM.

## Core Scripts
1. `install.sh` — Main automated installer (idempotent, uses `set -euo pipefail`).
2. `uninstall.sh` — Complete stack removal (containers, crons, logrotate, SSL cert).
3. `backup.sh` — Daily backup of MySQL DB + mautic_data volume (requires `PROJECT_ROOT`).
4. `restore.sh` — Restores MySQL + volume from latest backup in `backups/`.
5. `scripts/validate.sh` — Full health check (containers, HTTP, MySQL, Redis, worker).

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
  5. Redirect loop SSL: `local.php` precisa de `trusted_proxies => ['0.0.0.0/0']` + Nginx precisa de `X-Forwarded-Proto https` hardcoded no bloco 443. Nunca incluir `listen 443 ssl` antes do Certbot rodar (`nginx -t` falha sem certificado).

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
