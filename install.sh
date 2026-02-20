#!/bin/bash

# ==============================================================================
# MAUTIC STACK INSTALLER (v5.2.6)
# ==============================================================================

# Auto-correção para finais de linha Windows (CRLF)
if grep -q $'\r' "$0" 2>/dev/null; then
    sed -i 's/\r$//' "$0" 2>/dev/null && exec bash "$0" "$@"
fi

set -euo pipefail # Fail fast em erros

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# 1. Carregar Bibliotecas Centralizadas
source "${PROJECT_ROOT}/scripts/lib/colors.sh"
source "${PROJECT_ROOT}/scripts/lib/logging.sh"
source "${PROJECT_ROOT}/scripts/lib/utils.sh"

# 2. Trap e Limpeza
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Instalação interrompida com erro no estágio: ${CURRENT_STAGE:-desconhecido}"
    fi
}
trap cleanup EXIT

# ==============================================================================
# EXECUÇÃO PRINCIPAL
# ==============================================================================

main() {
    # Redirecionar output para log e terminal simultaneamente
    mkdir -p /var/log/mautic-stack
    exec > >(tee -i /var/log/mautic-stack/install_verbose.log) 2>&1

    clear
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}          MAUTIC STACK INSTALLER v5.2.6            ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo

    # 1. Validar Root
    validate_root

    # 2. Pre-flight Checks
    CURRENT_STAGE="Pre-flight"
    source "${PROJECT_ROOT}/scripts/preflight.sh"
    pre_flight_checks

    # 3. Instalar Docker
    CURRENT_STAGE="Docker Install"
    source "${PROJECT_ROOT}/scripts/docker_install.sh"
    install_docker

    # 4. Idempotência / Verificação de Instalação Existente
    CURRENT_STAGE="Idempotency Check"
    if docker compose ps --services --filter "status=running" | grep -qi "mautic"; then
        log_warning "Containers do Mautic já estão em execução."
        read -p "Deseja [r]einiciar, [a]tualizar ou [s]air? (r/a/s) [s]: " action
        action=${action:-s}
        case "$action" in
            r) docker compose restart ;;
            a) log_info "Prosseguindo com a verificação/atualização..." ;;
            *) exit 0 ;;
        esac
    fi

    # 5. Gerar local.php
    CURRENT_STAGE="Config Generation"
    log_info "Preparando arquivos de configuração..."
    if [ ! -f "${PROJECT_ROOT}/config/local.php" ]; then
        envsubst < "${PROJECT_ROOT}/config/local.php.tpl" > "${PROJECT_ROOT}/config/local.php"
        # [GUARDA RACE CONDITION]
        [ -f "${PROJECT_ROOT}/config/local.php" ] || { log_error "local.php não foi gerado. Abortando."; exit 1; }
        log_success "Arquivo config/local.php gerado."
    else
        log_info "config/local.php já existe. Poupando geração."
    fi

    # 6. Docker Compose Up
    CURRENT_STAGE="Docker Compose Up"
    log_info "Iniciando containers via Docker Compose..."
    docker compose pull
    if ! docker compose up -d; then
        log_error "Falha ao iniciar containers via Docker Compose. Consultando logs..."
        docker compose logs --tail=20
        exit 1
    fi

    # Aguardar healthchecks
    log_info "Aguardando containers ficarem saudáveis (timeout 120s)..."
    local timeout=120
    local start_time=$(date +%s)
    while true; do
        if docker compose ps | grep -q "starting"; then
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            if [ $elapsed -gt $timeout ]; then
                log_error "Timeout aguardando healthchecks."
                break
            fi
            sleep 5
        else
            log_success "Containers prontos."
            break
        fi
    done

    # 7. Instalação Headless Mautic
    log_info "Verificando status de instalação do Mautic..."
    # Usar mautic:about para verificação robusta
    if ! docker compose exec -T mautic php bin/console about 2>&1 | grep -qi "installed.*yes"; then
        log_info "Mautic não instalado. Iniciando instalação CLI..."
        docker compose exec -T mautic php bin/console mautic:install \
            --db-host=mysql --db-port=3306 \
            --db-name=${MYSQL_DATABASE} \
            --db-user=${MYSQL_USER} \
            --db-password=${MYSQL_PASSWORD} \
            --admin-email=${MAUTIC_ADMIN_EMAIL} \
            --admin-firstname=${MAUTIC_ADMIN_FIRSTNAME} \
            --admin-lastname=${MAUTIC_ADMIN_LASTNAME} \
            --admin-password=${MAUTIC_ADMIN_PASSWORD} \
            "${MAUTIC_URL}"
        
        # Corrigir permissões iniciais no volume
        docker compose exec -T mautic chown -R www-data:www-data .
        log_success "Mautic instalado com sucesso via CLI."
    else
        log_info "Mautic já consta como instalado. Pulando mautic:install."
    fi

    # 8. Pós-Instalação / Cache
    log_info "Limpando cache e gerando assets..."
    docker compose exec -T mautic php bin/console cache:clear
    docker compose exec -T mautic php bin/console mautic:assets:generate
    docker compose exec -T mautic php bin/console mautic:segments:update

    # 9. Configurar Cron Jobs
    log_info "Configurando Cron Jobs no host..."
    INSTALL_DIR="$(pwd)"
    CRON_FILE="/etc/cron.d/mautic-stack"
    
    cat > "/tmp/mautic-cron" <<EOF
# Cron Jobs para Mautic Stack ($INSTALL_DIR)
*/5 * * * * root docker compose -f $INSTALL_DIR/docker-compose.yml exec -T mautic php bin/console mautic:segments:update >> /var/log/mautic-stack/cron.log 2>&1
*/5 * * * * root docker compose -f $INSTALL_DIR/docker-compose.yml exec -T mautic php bin/console mautic:campaigns:trigger >> /var/log/mautic-stack/cron.log 2>&1
*/10 * * * * root docker compose -f $INSTALL_DIR/docker-compose.yml exec -T mautic php bin/console mautic:emails:send >> /var/log/mautic-stack/cron.log 2>&1
*/30 * * * * root docker compose -f $INSTALL_DIR/docker-compose.yml exec -T mautic php bin/console mautic:social:monitoring >> /var/log/mautic-stack/cron.log 2>&1
EOF
    mv "/tmp/mautic-cron" "$CRON_FILE"
    chmod 644 "$CRON_FILE"
    log_success "Cron jobs instalados em $CRON_FILE"

    # 10. Configurar Nginx (Opcional)
    if [[ "$USE_DOMAIN" == "true" ]]; then
        source "${PROJECT_ROOT}/scripts/nginx_setup.sh"
        setup_nginx "$DOMAIN" "$MAUTIC_PORT" "y" "$SSL_EMAIL"
    else
        echo
        read -p "Deseja configurar um domínio com Nginx e SSL agora? (s/n) [n]: " setup_ans
        if [[ "$setup_ans" =~ ^[SsYy]$ ]]; then
            read -p "Digite o domínio (ex: mautic.exemplo.com): " domain
            read -p "Deseja SSL automático? (s/n) [s]: " use_ssl
            use_ssl=${use_ssl:-s}
            source "${PROJECT_ROOT}/scripts/nginx_setup.sh"
            setup_nginx "$domain" "$MAUTIC_PORT" "$use_ssl" "$MAUTIC_ADMIN_EMAIL"
        fi
    fi

    # 11. Validação Final
    source "${PROJECT_ROOT}/scripts/validate.sh"
    validate_stack

    echo
    log_success "═══════════════════════════════════════════════════"
    log_success "      INSTALAÇÃO CONCLUÍDA COM SUCESSO!            "
    log_success "═══════════════════════════════════════════════════"
    echo
    echo -e "  🚀 URL: ${MAUTIC_URL}"
    echo -e "  👤 Admin: ${MAUTIC_ADMIN_EMAIL}"
    echo -e "  🔑 Senha: ${MAUTIC_ADMIN_PASSWORD}"
    echo -e "  📁 Logs: /var/log/mautic-stack/"
    echo -e "  💾 Backup: Execute ./backup.sh"
    echo
}

main "$@"
