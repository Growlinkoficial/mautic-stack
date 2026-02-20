#!/bin/bash
set -euo pipefail

# ==============================================================================
# MAUTIC STACK RESTORE
# ==============================================================================

# Auto-correção para finais de linha Windows (CRLF)
if grep -q $'\r' "$0" 2>/dev/null; then
    sed -i 's/\r$//' "$0" 2>/dev/null && exec bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Carregar env vars e libs
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a; source "${PROJECT_ROOT}/.env"; set +a
else
    echo "Erro: Arquivo .env não encontrado em $PROJECT_ROOT"
    exit 1
fi
[[ -f "${PROJECT_ROOT}/scripts/lib/logging.sh" ]] && source "${PROJECT_ROOT}/scripts/lib/logging.sh"

# ==============================================================================
# SELEÇÃO DE BACKUP
# ==============================================================================

BACKUP_DIR="${PROJECT_ROOT}/backups"

if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    log_error "Nenhum backup encontrado em $BACKUP_DIR"
    exit 1
fi

log_info "Backups disponíveis:"
echo ""
ls -lht "$BACKUP_DIR" | grep -v "^total"
echo ""

# Selecionar backup do MySQL
SQL_FILES=("${BACKUP_DIR}"/mysql_backup_*.sql)
if [ ${#SQL_FILES[@]} -eq 0 ]; then
    log_error "Nenhum arquivo .sql encontrado em $BACKUP_DIR"
    exit 1
fi

log_info "Selecionando backup mais recente automaticamente..."
SQL_FILE=$(ls -t "${BACKUP_DIR}"/mysql_backup_*.sql | head -n1)
TAR_FILE=$(ls -t "${BACKUP_DIR}"/mautic_files_*.tar.gz 2>/dev/null | head -n1 || true)

log_warning "Arquivo SQL que será restaurado: $(basename "$SQL_FILE")"
if [ -n "$TAR_FILE" ]; then
    log_warning "Arquivo de volumes que será restaurado: $(basename "$TAR_FILE")"
fi
echo ""
read -p "Confirmar restauração? Isso sobrescreve os dados atuais. (s/n): " confirm
if [[ ! $confirm =~ ^[SsYy]$ ]]; then
    log_info "Restauração cancelada."
    exit 0
fi

# ==============================================================================
# RESTAURAÇÃO
# ==============================================================================

# 1. Parar containers
log_info "Parando containers para restauração segura..."
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" stop mautic mautic_worker

# 2. Restaurar MySQL
log_info "Restaurando banco de dados MySQL a partir de $(basename "$SQL_FILE")..."
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql \
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" < "$SQL_FILE"
log_success "Banco de dados MySQL restaurado."

# 3. Restaurar volume mautic_data (se houver tarball)
if [ -n "$TAR_FILE" ]; then
    log_info "Restaurando arquivos do volume a partir de $(basename "$TAR_FILE")..."
    VOLUME_NAME="${COMPOSE_PROJECT_NAME:-mautic-stack}_mautic_data"
    docker run --rm \
        -v "${VOLUME_NAME}:/data" \
        -v "${BACKUP_DIR}:/backup" \
        alpine sh -c "rm -rf /data/* && tar xzf /backup/$(basename "$TAR_FILE") -C /data"
    log_success "Arquivos do volume Mautic restaurados."
fi

# 4. Reiniciar containers
log_info "Reiniciando containers..."
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" start mautic mautic_worker

log_success "Restauração concluída com sucesso!"
echo -e "  🌐 URL: ${MAUTIC_URL:-http://localhost:${MAUTIC_PORT:-8080}}"
