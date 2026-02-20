#!/bin/bash

# Carregar libs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/lib/logging.sh" ]] && source "${SCRIPT_DIR}/lib/logging.sh"
[[ -f "${SCRIPT_DIR}/lib/utils.sh" ]] && source "${SCRIPT_DIR}/lib/utils.sh"

pre_flight_checks() {
    log_info "Iniciando Pre-flight checks..."

    # 0. Dependências Básicas
    if ! command -v envsubst &> /dev/null; then
        log_info "Instalando dependências básicas (gettext-base)..."
        apt-get update -qq && apt-get install -y gettext-base
    fi

    # 1. SO Check (Ubuntu 24.04 recomendado)
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            log_warning "Este script foi validado para Ubuntu. Sistema detectado: $NAME. Proceda com cautela."
        fi
    fi

    # 2. Hardware Checks
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 1500 ]; then
        log_warning "Memória RAM insuficiente detectada ($total_ram MB). Mautic requer pelo menos 1.5GB."
    fi

    local free_disk=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ "$free_disk" =~ ^[0-9]+$ ]] && [ "$free_disk" -lt 10 ]; then
        log_warning "Pouco espaço em disco livre ($free_disk GB). Recomendado pelo menos 10GB."
    fi

    # 3. Environment Check
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        if [ -f "${PROJECT_ROOT}/.env.example" ]; then
            log_info "Arquivo .env não encontrado. Criando a partir de .env.example..."
            cp "${PROJECT_ROOT}/.env.example" "${PROJECT_ROOT}/.env"
            log_warning "Por favor, edite o arquivo .env com suas credenciais antes de prosseguir."
            # Neste fluxo automático, assumiremos que o install.sh lidará com a edição ou usará valores default
        else
            log_error "Erro crítico: .env e .env.example não encontrados."
            exit 1
        fi
    fi
    
    # Carregar variáveis do .env
    set -a; source "${PROJECT_ROOT}/.env"; set +a

    # 4. Port Check
    if check_port_in_use "${MAUTIC_PORT:-8080}"; then
        log_error "A porta ${MAUTIC_PORT:-8080} já está em uso por outro processo."
        exit 1
    fi

    log_success "Pre-flight checks concluídos com sucesso."
}

# Se executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    pre_flight_checks
fi
