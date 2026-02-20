#!/bin/bash

# Carregar libs
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${LIB_DIR}/logging.sh" ]] && source "${LIB_DIR}/logging.sh"

validate_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Este script deve ser executado como root (use sudo)"
        exit 1
    fi
}

validate_domain() {
    local domain="$1"
    if [[ ! $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Formato de domínio inválido: $domain"
        return 1
    fi
    return 0
}

validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Porta inválida: $port (deve ser entre 1-65535)"
        return 1
    fi
    return 0
}

validate_email() {
    local email="$1"
    if [[ ! $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Formato de email inválido: $email"
        return 1
    fi
    return 0
}

check_port_in_use() {
    local port="$1"
    if (command -v netstat >/dev/null && netstat -tuln | grep -q ":$port ") || \
       (command -v ss >/dev/null && ss -tuln | grep -q ":$port "); then
        return 0  # Porta em uso
    else
        return 1  # Porta livre
    fi
}

check_domain_exists() {
    local domain="$1"
    local config_name=$(echo "$domain" | sed 's/\./-/g')
    local nginx_sites="/etc/nginx/sites-available"
    
    if [ -f "$nginx_sites/mautic-$config_name" ] || [ -f "$nginx_sites/$config_name" ]; then
        return 0  # Domínio já configurado
    else
        return 1  # Domínio não configurado
    fi
}

check_dns() {
    local domain="$1"
    local server_ip=$(hostname -I | awk '{print $1}')
    local domain_ip=""
    
    if command -v dig >/dev/null; then
        domain_ip=$(dig +short "$domain" | tail -n1)
    elif command -v host >/dev/null; then
        domain_ip=$(host "$domain" | awk '/has address/ { print $4 }' | tail -n1)
    fi
    
    log_info "Verificando DNS para $domain..."
    
    if [ -z "$domain_ip" ]; then
        log_warning "O domínio $domain não resolve para nenhum IP"
        return 1
    elif [ "$domain_ip" != "$server_ip" ]; then
        log_warning "Domínio resolve para: $domain_ip (IP do servidor: $server_ip)"
        return 1
    else
        log_success "DNS configurado corretamente ($domain_ip)"
        return 0
    fi
}
