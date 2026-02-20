#!/bin/bash

# ==============================================================================
# MAUTIC STACK UNINSTALLER
# ==============================================================================

# Auto-correção para finais de linha Windows (CRLF)
if grep -q $'\r' "$0" 2>/dev/null; then
    sed -i 's/\r$//' "$0" 2>/dev/null && exec bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

source "${PROJECT_ROOT}/scripts/lib/colors.sh"
source "${PROJECT_ROOT}/scripts/lib/logging.sh"
source "${PROJECT_ROOT}/scripts/lib/utils.sh"

validate_root

echo -e "${RED}═══════════════════════════════════════════════════${NC}"
echo -e "${RED}          MAUTIC STACK UNINSTALLER                 ${NC}"
echo -e "${RED}═══════════════════════════════════════════════════${NC}"
echo
log_warning "Esta ação removerá containers, configurações e cron jobs."

read -p "Tem certeza que deseja continuar? (s/n): " confirm
if [[ ! $confirm =~ ^[SsYy]$ ]]; then
    log_info "Operação cancelada."
    exit 0
fi

# 1. Remover Cron Jobs
log_info "Removendo cron jobs..."
rm -f /etc/cron.d/mautic-stack
log_success "Cron jobs removidos."

# 2. Docker Compose Down
log_info "Parando e removendo containers..."
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" down

read -p "Deseja remover também os volumes (DADOS DO BANCO E ARQUIVOS)? (s/n): " confirm_v
if [[ $confirm_v =~ ^[SsYy]$ ]]; then
    log_info "Removendo volumes..."
    docker compose -f "${PROJECT_ROOT}/docker-compose.yml" down -v
    log_success "Volumes removidos."
fi

# 3. Nginx Config
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a; source "${PROJECT_ROOT}/.env"; set +a
    if [ ! -z "$DOMAIN" ]; then
        log_info "Removendo configuração Nginx para $DOMAIN..."
        config_name=$(echo "$DOMAIN" | sed 's/\./-/g')
        rm -f "/etc/nginx/sites-enabled/mautic-$config_name"
        rm -f "/etc/nginx/sites-available/mautic-$config_name"
        
        # Remover Certificado SSL se existir
        if command -v certbot &> /dev/null; then
            if certbot certificates 2>/dev/null | grep -q "$DOMAIN"; then
                log_info "Removendo certificado SSL..."
                certbot delete --cert-name "$DOMAIN" --non-interactive || true
            fi
        fi
        
        nginx -t &> /dev/null && systemctl reload nginx
        log_success "Configuração Nginx removida."
    fi
fi

# 4. Cleanup Local
rm -f "${PROJECT_ROOT}/config/local.php"
log_info "Configuração local (local.php) removida."

# 5. Logs
echo
read -p "Deseja remover os logs em /var/log/mautic-stack/? (s/n): " confirm_l
if [[ $confirm_l =~ ^[SsYy]$ ]]; then
    rm -rf /var/log/mautic-stack/
    log_success "Diretório de logs removido."
fi

log_success "Desinstalação concluída."
