#!/bin/bash

# ==============================================================================
# MAUTIC STACK INSTALLER (v5)
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
# WIZARD DE CONFIGURAÇÃO — cria o .env interativamente se não existir
# ==============================================================================

wizard_setup_env() {
    local env_file="${PROJECT_ROOT}/.env"

    # Idempotência: se .env já existe, só carrega e sai
    if [ -f "$env_file" ]; then
        log_info ".env já existe. Usando configurações existentes."
        set -a; source "$env_file"; set +a
        return 0
    fi

    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}          CONFIGURAÇÃO DO AMBIENTE MAUTIC           ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "  Nenhum arquivo .env encontrado. Vamos configurar agora."
    echo

    # ──────────────────────────────────────────────────────
    # [1/3] DOMÍNIO
    # ──────────────────────────────────────────────────────
    echo -e "${BLUE}[1/3] DOMÍNIO${NC}"
    read -p "  Deseja configurar domínio/subdomínio? (s = domínio próprio, n = localhost) [n]: " _use_domain
    _use_domain=${_use_domain:-n}

    local WIZARD_USE_DOMAIN="false"
    local WIZARD_DOMAIN="localhost"
    local WIZARD_SSL_EMAIL=""
    local WIZARD_MAUTIC_URL

    if [[ "$_use_domain" =~ ^[SsYy]$ ]]; then
        WIZARD_USE_DOMAIN="true"
        read -p "  Informe o domínio (ex: mautic.suaempresa.com): " WIZARD_DOMAIN
        while [[ -z "$WIZARD_DOMAIN" ]]; do
            read -p "  Domínio não pode ser vazio. Informe o domínio: " WIZARD_DOMAIN
        done
        read -p "  Email para o certificado SSL (Let's Encrypt): " WIZARD_SSL_EMAIL
        while [[ -z "$WIZARD_SSL_EMAIL" || "$WIZARD_SSL_EMAIL" == *"example.com"* ]]; do
            read -p "  Email inválido (não use example.com). Informe o email: " WIZARD_SSL_EMAIL
        done
        WIZARD_MAUTIC_URL="https://${WIZARD_DOMAIN}"
    else
        log_info "  → Instalação em modo localhost."
        WIZARD_USE_DOMAIN="false"
        WIZARD_DOMAIN="localhost"
    fi
    echo

    # ──────────────────────────────────────────────────────
    # [2/3] PORTA
    # ──────────────────────────────────────────────────────
    echo -e "${BLUE}[2/3] PORTA${NC}"
    read -p "  Porta de acesso ao Mautic [8080]: " WIZARD_PORT
    WIZARD_PORT=${WIZARD_PORT:-8080}
    # Validar que é número
    while ! [[ "$WIZARD_PORT" =~ ^[0-9]+$ ]]; do
        read -p "  Porta inválida. Informe um número de porta [8080]: " WIZARD_PORT
        WIZARD_PORT=${WIZARD_PORT:-8080}
    done
    # Ajustar URL se ainda estiver em localhost
    if [ "$WIZARD_USE_DOMAIN" == "false" ]; then
        WIZARD_MAUTIC_URL="http://localhost:${WIZARD_PORT}"
    fi
    echo

    # ──────────────────────────────────────────────────────
    # [3/3] ADMINISTRADOR
    # ──────────────────────────────────────────────────────
    echo -e "${BLUE}[3/3] ADMINISTRADOR${NC}"
    read -p "  Email do administrador: " WIZARD_ADMIN_EMAIL
    while [[ -z "$WIZARD_ADMIN_EMAIL" || "$WIZARD_ADMIN_EMAIL" == *"example.com"* ]]; do
        read -p "  Email inválido. Informe um email real: " WIZARD_ADMIN_EMAIL
    done
    read -p "  Primeiro nome: " WIZARD_ADMIN_FIRSTNAME
    WIZARD_ADMIN_FIRSTNAME=${WIZARD_ADMIN_FIRSTNAME:-Admin}
    read -p "  Sobrenome: " WIZARD_ADMIN_LASTNAME
    WIZARD_ADMIN_LASTNAME=${WIZARD_ADMIN_LASTNAME:-User}
    echo

    # ──────────────────────────────────────────────────────
    # GERAÇÃO DE SENHAS
    # ──────────────────────────────────────────────────────
    log_info "Gerando senhas seguras..."
    local GEN_MYSQL_ROOT_PASSWORD
    local GEN_MYSQL_PASSWORD
    local GEN_ADMIN_PASSWORD
    local GEN_REDIS_PASSWORD
    GEN_MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
    GEN_MYSQL_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
    GEN_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
    GEN_REDIS_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)

    # ──────────────────────────────────────────────────────
    # ESCREVER .env
    # ──────────────────────────────────────────────────────
    cat > "$env_file" <<EOF
# ==============================================================================
# MAUTIC STACK - ENVIRONMENT VARIABLES
# Gerado automaticamente em $(date '+%Y-%m-%d %H:%M:%S')
# ==============================================================================

# Compose Project Name (evita colisão de volumes/redes)
COMPOSE_PROJECT_NAME=mautic-stack

# ------------------------------------------------------------------------------
# MAUTIC CONFIGURATION
# ------------------------------------------------------------------------------
MAUTIC_PORT=${WIZARD_PORT}
MAUTIC_URL=${WIZARD_MAUTIC_URL}

# Admin Inicial (criado automaticamente via CLI)
MAUTIC_ADMIN_USERNAME=admin
MAUTIC_ADMIN_EMAIL=${WIZARD_ADMIN_EMAIL}
MAUTIC_ADMIN_PASSWORD=${GEN_ADMIN_PASSWORD}
MAUTIC_ADMIN_FIRSTNAME=${WIZARD_ADMIN_FIRSTNAME}
MAUTIC_ADMIN_LASTNAME=${WIZARD_ADMIN_LASTNAME}

# ------------------------------------------------------------------------------
# DATABASE CONFIGURATION (MySQL 8.0)
# ------------------------------------------------------------------------------
MYSQL_ROOT_PASSWORD=${GEN_MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=mautic
MYSQL_USER=mautic
MYSQL_PASSWORD=${GEN_MYSQL_PASSWORD}

# ------------------------------------------------------------------------------
# CACHE CONFIGURATION (Redis 7)
# ------------------------------------------------------------------------------
REDIS_PASSWORD=${GEN_REDIS_PASSWORD}

# ------------------------------------------------------------------------------
# DOMAIN & NGINX (configurado pelo wizard)
# ------------------------------------------------------------------------------
USE_DOMAIN=${WIZARD_USE_DOMAIN}
DOMAIN=${WIZARD_DOMAIN}
SSL_EMAIL=${WIZARD_SSL_EMAIL}
EOF
    chmod 600 "$env_file"

    echo
    log_success ".env criado em: ${env_file}"
    log_info    "Guarde suas credenciais! Todas as senhas foram salvas nesse arquivo."
    echo

    # Confirmação antes de prosseguir
    read -p "Prosseguir com a instalação? (s/n) [s]: " _proceed
    _proceed=${_proceed:-s}
    if [[ ! "$_proceed" =~ ^[SsYy]$ ]]; then
        log_info "Instalação cancelada pelo usuário. O .env foi mantido."
        exit 0
    fi

    # Carregar vars no processo atual
    set -a; source "$env_file"; set +a
}

# ==============================================================================
# EXECUÇÃO PRINCIPAL
# ==============================================================================

main() {
    # Redirecionar output para log e terminal simultaneamente
    mkdir -p /var/log/mautic-stack
    exec > >(tee -i /var/log/mautic-stack/install_verbose.log) 2>&1

    clear
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}              MAUTIC STACK INSTALLER v5            ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo

    # 0. Wizard de Configuração (cria .env se não existir)
    CURRENT_STAGE="Wizard"
    wizard_setup_env

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
    if docker compose -f "${PROJECT_ROOT}/docker-compose.yml" ps --services --filter "status=running" | grep -qi "mautic"; then
        log_warning "Containers do Mautic já estão em execução."
        read -p "Deseja [r]einiciar, [a]tualizar ou [s]air? (r/a/s) [s]: " action
        action=${action:-s}
        case "$action" in
            r) docker compose -f "${PROJECT_ROOT}/docker-compose.yml" restart ;;
            a) log_info "Prosseguindo com a verificação/atualização..." ;;
            *) exit 0 ;;
        esac
    fi

    # 5. Gerar local.php
    CURRENT_STAGE="Config Generation"
    log_info "Preparando arquivos de configuração..."
    if [ ! -f "${PROJECT_ROOT}/config/local.php" ]; then
        # CRÍTICO: usar lista explícita de vars para NÃO substituir $parameters do PHP
        # envsubst sem lista substitui qualquer $VAR, incluindo $parameters → quebra o PHP
        envsubst '${MYSQL_DATABASE}${MYSQL_USER}${MYSQL_PASSWORD}${REDIS_PASSWORD}${MAUTIC_URL}' \
            < "${PROJECT_ROOT}/config/local.php.tpl" \
            > "${PROJECT_ROOT}/config/local.php"
        # [GUARDA RACE CONDITION]
        [ -f "${PROJECT_ROOT}/config/local.php" ] || { log_error "local.php não foi gerado. Abortando."; exit 1; }
        # Sanity check: garantir que $parameters não foi corrompido
        grep -q '\$parameters' "${PROJECT_ROOT}/config/local.php" || {
            log_error "local.php corrompido: \$parameters foi substituído pelo envsubst. Abortando."
            exit 1
        }
        log_success "Arquivo config/local.php gerado."
    else
        log_info "config/local.php já existe. Poupando geração."
    fi

    # 6. Docker Compose Up
    CURRENT_STAGE="Docker Compose Up"
    log_info "Baixando imagens base (Docker Pull)..."
    
    # Forçamos a saída para o terminal direto para tentar manter a UI nativa
    # sem poluir o log verboso com sequências de escape.
    if ! docker compose -f "${PROJECT_ROOT}/docker-compose.yml" pull > /dev/tty 2>&1; then
        log_error "Falha ao baixar imagens. Verifique sua conexão."
        exit 1
    fi
    log_success "Imagens base baixadas com sucesso."

    # Construir imagem customizada (Dockerfile com libavif15 para extensão gd)
    # ERR-20260220-015: mautic/mautic:5-apache requer libavif15 que não vem no Debian base
    log_info "Construindo imagem customizada (Dockerfile)..."
    if ! docker compose -f "${PROJECT_ROOT}/docker-compose.yml" build > /dev/tty 2>&1; then
        log_error "Falha ao construir imagem customizada. Verifique o Dockerfile."
        exit 1
    fi
    log_success "Imagem customizada construída com sucesso."

    log_info "Iniciando containers via Docker Compose..."
    if ! docker compose -f "${PROJECT_ROOT}/docker-compose.yml" up -d; then
        log_error "Falha ao iniciar containers via Docker Compose. Consultando logs..."
        docker compose -f "${PROJECT_ROOT}/docker-compose.yml" logs --tail=20
        exit 1
    fi

    # Aguardar healthchecks
    log_info "Aguardando containers ficarem saudáveis (timeout 120s)..."
    local timeout=120
    local start_time=$(date +%s)
    while true; do
        if docker compose -f "${PROJECT_ROOT}/docker-compose.yml" ps | grep -q "starting"; then
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

    # 7. Aguardar inicialização dos arquivos Mautic
    # A imagem mautic/mautic:5-apache copia os arquivos para o volume na 1a execução.
    # O health check HTTP passa antes desse processo terminar. (LRN-20260220-007)
    CURRENT_STAGE="Mautic File Init"
    log_info "Aguardando arquivos do Mautic serem inicializados no volume (bin/console)..."
    local console_timeout=180
    local console_start=$(date +%s)
    until docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mautic test -f /var/www/html/bin/console 2>/dev/null; do
        local now=$(date +%s)
        local waited_console=$((now - console_start))
        if [ $waited_console -ge $console_timeout ]; then
            log_error "Timeout (${console_timeout}s) aguardando bin/console. O volume pode estar vazio."
            docker compose -f "${PROJECT_ROOT}/docker-compose.yml" logs mautic --tail=30
            exit 1
        fi
        log_info "  bin/console ainda não disponível... (${waited_console}s)"
        sleep 10
    done
    log_success "Arquivos do Mautic prontos."

    # 8. Instalação Headless Mautic
    CURRENT_STAGE="Mautic Install"
    log_info "Verificando status de instalação do Mautic..."

    # Detectar se já instalado via local.php (mais confíiavel que `about` que não tem output de install status)
    local already_installed=false
    if grep -q "'installed' => true" "${PROJECT_ROOT}/config/local.php" 2>/dev/null; then
        already_installed=true
    fi

    if [ "$already_installed" = "false" ]; then
        log_info "Mautic não instalado. Iniciando instalação CLI..."
        docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T -w /var/www/html mautic \
            php bin/console mautic:install \
            --db_host=mysql --db_port=3306 \
            --db_name="${MYSQL_DATABASE}" \
            --db_user="${MYSQL_USER}" \
            --db_password="${MYSQL_PASSWORD}" \
            --admin_email="${MAUTIC_ADMIN_EMAIL}" \
            --admin_username="${MAUTIC_ADMIN_USERNAME:-admin}" \
            --admin_firstname="${MAUTIC_ADMIN_FIRSTNAME}" \
            --admin_lastname="${MAUTIC_ADMIN_LASTNAME}" \
            --admin_password="${MAUTIC_ADMIN_PASSWORD}" \
            "${MAUTIC_URL}"

        # Marcar como instalado no local.php do HOST
        # O mautic:install CLI não atualiza o arquivo bind-mounted automaticamente
        sed -i "s/'installed' => false,/'installed' => true,/" "${PROJECT_ROOT}/config/local.php"
        grep -q "'installed' => true" "${PROJECT_ROOT}/config/local.php" \
            && log_success "local.php marcado como installed=true." \
            || log_warning "Não foi possível marcar installed=true no local.php — verifique manualmente."

        # Corrigir permissões no volume
        # Escopo amplo primeiro para garantir www-data em todos os arquivos
        docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mautic chown -R www-data:www-data /var/www/html
        # Fix: var/cache e var/logs precisam de permissão de escrita para o Mautic
        # Sem isso, downloads de pacotes de idioma (ex: pt_BR.zip) falham com Permission denied
        # (LanguageHelper.php tenta escrever em /var/www/html/var/cache/prod/)
        docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mautic chmod -R 775 /var/www/html/var/cache
        docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mautic chmod -R 775 /var/www/html/var/logs
        log_success "Mautic instalado com sucesso via CLI."
    else
        log_info "Mautic já consta como instalado (local.php: installed=true). Pulando mautic:install."
    fi

    # 9. Pós-Instalação / Cache
    log_info "Limpando cache e gerando assets..."
    docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T -w /var/www/html mautic php bin/console cache:clear
    docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T -w /var/www/html mautic php bin/console mautic:assets:generate
    docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T -w /var/www/html mautic php bin/console mautic:segments:update

    # 9. Configurar Cron Jobs
    log_info "Configurando Cron Jobs no host..."
    INSTALL_DIR="${PROJECT_ROOT}"
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

    # WARN-007: Configuração de rotação de logs para evitar disco cheio
    log_info "Configurando rotação de logs (logrotate)..."
    cat > /etc/logrotate.d/mautic-stack <<'LOGROTATE'
/var/log/mautic-stack/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    copytruncate
}
LOGROTATE
    log_success "Logrotate configurado: /etc/logrotate.d/mautic-stack (14 dias, compress)"

    # 10. Configurar Nginx (se domínio foi configurado no wizard)
    if [[ "${USE_DOMAIN:-false}" == "true" ]]; then
        log_info "Configurando Nginx + SSL para ${DOMAIN}..."
        source "${PROJECT_ROOT}/scripts/nginx_setup.sh"
        setup_nginx "$DOMAIN" "$MAUTIC_PORT" "y" "$SSL_EMAIL"
    fi

    # 11. Validação Final
    source "${PROJECT_ROOT}/scripts/validate.sh"
    validate_stack

    echo
    log_success "═══════════════════════════════════════════════════"
    log_success "      INSTALAÇÃO CONCLUÍDA COM SUCESSO!            "
    log_success "═══════════════════════════════════════════════════"
    echo
    echo -e "  🚀 URL:    ${MAUTIC_URL}"
    echo -e "  👤 Admin:  ${MAUTIC_ADMIN_EMAIL}"
    echo -e "  🔑 Senha:  (salva no .env — nunca exibida por segurança)"
    echo -e "  📁 Logs:   /var/log/mautic-stack/"
    echo -e "  📄 .env:   ${PROJECT_ROOT}/.env"
    echo -e "  💾 Backup: Execute ./backup.sh"
    echo
}

main "$@"
