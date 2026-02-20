#!/bin/bash

# Carregar libs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/lib/logging.sh" ]] && source "${SCRIPT_DIR}/lib/logging.sh"

validate_stack() {
    log_info "Iniciando validação do Mautic Stack..."

    # Carregar variáveis do .env (necessário para COMPOSE_PROJECT_NAME)
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        set -a; source "${PROJECT_ROOT}/.env"; set +a
    else
        log_warning "Arquivo .env não encontrado em $PROJECT_ROOT. Usando padrões do Docker Compose."
    fi

    # 1. Containers Running
    local running_count=$(docker compose -f "${PROJECT_ROOT}/docker-compose.yml" ps | grep -E "mautic|mautic_worker|mysql|redis" | grep -c -i "running\|Up")
    if [ "$running_count" -ge 4 ]; then
        log_success "Todos os 4 containers estão em execução."
    else
        log_error "Apenas $running_count de 4 containers estão rodando corretamente."
        docker compose -f "${PROJECT_ROOT}/docker-compose.yml" ps
        return 1
    fi

    # 2. HTTP Check (Login page)
    local url="http://localhost:${MAUTIC_PORT:-8080}/s/login"
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    if [ "$http_code" == "200" ]; then
        log_success "Mautic respondendo com HTTP 200 na página de login."
    else
        log_warning "Mautic respondeu com HTTP $http_code. Verifique os logs do container mautic."
    fi

    # 3. MySQL Ping
    if docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql mysqladmin ping -u root -p"${MYSQL_ROOT_PASSWORD}" --silent; then
        log_success "Conexão MySQL OK."
    else
        log_error "Falha na conexão MySQL."
    fi

    # 4. Redis Ping
    if docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T redis redis-cli --no-auth-warning -a "${REDIS_PASSWORD}" ping | grep -q "PONG"; then
        log_success "Conexão Redis OK."
    else
        log_error "Falha na conexão Redis."
    fi

    # 5. Mautic Redis Cache Check
    if docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mautic php bin/console debug:config mautic_cache 2>/dev/null | grep -qi "redis"; then
        log_success "Mautic utilizando Redis como adaptador de cache."
    else
        log_warning "Redis não detectado como o adaptador de cache ativo no Mautic."
    fi

    log_success "Validação concluída."
    return 0
}

# Se executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_stack
fi
