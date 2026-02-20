#!/bin/bash

# Carregar libs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/lib/logging.sh" ]] && source "${SCRIPT_DIR}/lib/logging.sh"

install_docker() {
    log_info "Verificando se o Docker já está instalado..."

    if command -v docker &> /dev/null; then
        log_success "Docker detectado: $(docker --version)"
    else
        log_info "Docker não encontrado. Iniciando instalação oficial..."
        
        # Instalação oficial via get.docker.com
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        
        # Iniciar e habilitar serviço
        systemctl enable --now docker
        log_success "Docker instalado com sucesso."
    fi

    if docker compose version &> /dev/null; then
        log_success "Docker Compose V2 detectado: $(docker compose version)"
    else
        log_error "Docker Compose V2 não detectado. A versão do Docker instalada pode ser antiga."
        exit 1
    fi
}

# Se executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_docker
fi
