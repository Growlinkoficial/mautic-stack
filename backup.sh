#!/bin/bash
set -euo pipefail

# Carregar env vars para execução standalone
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a; source "${PROJECT_ROOT}/.env"; set +a
else
    echo "Erro: Arquivo .env não encontrado em $PROJECT_ROOT"
    exit 1
fi

# Carregar libs se disponíveis
[[ -f "${SCRIPT_DIR}/scripts/lib/logging.sh" ]] && source "${SCRIPT_DIR}/scripts/lib/logging.sh"

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${SCRIPT_DIR}/backups"
mkdir -p "$BACKUP_DIR"

echo "Iniciando backup do Mautic Stack..."

# 1. MySQL Dump
SQL_FILE="${BACKUP_DIR}/mysql_backup_${DATE}.sql"
if docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" > "$SQL_FILE"; then
    echo "[SUCESSO] Dump do MySQL salvo em $(basename "$SQL_FILE")"
else
    echo "[ERRO] Falha ao realizar dump do MySQL"
fi

# 2. Volume Tarball (mautic_data)
# Derivar nome do volume dinamicamente para evitar problemas se COMPOSE_PROJECT_NAME mudar
VOLUME_NAME="${COMPOSE_PROJECT_NAME:-mautic-stack}_mautic_data"
TAR_FILE="${BACKUP_DIR}/mautic_files_${DATE}.tar.gz"

if docker run --rm \
    -v "${VOLUME_NAME}:/data" \
    -v "${BACKUP_DIR}:/backup" \
    alpine tar czf "/backup/$(basename "$TAR_FILE")" -C /data . ; then
    echo "[SUCESSO] Arquivos do Mautic salvos em $(basename "$TAR_FILE")"
else
    echo "[ERRO] Falha ao realizar backup dos arquivos do volume"
fi

echo "Backup concluído. Arquivos salvos em $BACKUP_DIR"
