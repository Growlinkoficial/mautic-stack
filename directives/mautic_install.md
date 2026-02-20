---
priority: high
domain: infra
dependencies: [docker, nginx, mautic]
last_updated: 2026-02-19
---

# Directive: Mautic Stack Management

## Goal
Automate the deployment, maintenance, and backup of a Mautic 5.2.6 instance with Redis caching on Ubuntu 24.04.

## Inputs
- `.env` file with database and admin credentials.
- Ubuntu 24.04 server (standard).

## Core Scripts
1. `install.sh`: Main automated installer.
2. `uninstall.sh`: Complete stack removal.
3. `backup.sh`: Daily backup of DB and files.
4. `scripts/validate.sh`: Health check script.

## Success Criteria
- [ ] Containers `mautic`, `mautic_worker`, `mysql`, `redis` running.
- [ ] Mautic accessible via URL (HTTP 200).
- [ ] Redis cache adapter active in Mautic settings.
- [ ] Cron jobs active in `/etc/cron.d/mautic-stack`.

## Operational Procedures

### Installation
```bash
sudo ./install.sh
```

### Manual Backup
```bash
sudo ./backup.sh
```

### TroubleShooting
1. **Container Logs**: `docker compose logs -f [service]`
2. **Cron Logs**: `cat /var/log/mautic-stack/cron.log`
3. **Mautic Logs**: `docker compose exec mautic tail -f var/logs/mautic_prod.log`

## Edge Cases
- **Memory Issues**: Ensure server has > 1.5GB RAM.
- **Port Conflicts**: Check `MAUTIC_PORT` in `.env` if port 8080 is occupied.
- **DNS Issues**: Ensure domain points to server IP before running SSL setup.

## [2026-02-19] - Learning: Race Conditions
- **Issue**: `docker-compose.yml` creates a directory if `local.php` file is missing.
- **Solution**: Added validation in `install.sh` to ensure `local.php` exists before `up`.
