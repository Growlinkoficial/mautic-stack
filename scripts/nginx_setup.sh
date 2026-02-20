#!/bin/bash

# Carregar libs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/lib/logging.sh" ]] && source "${SCRIPT_DIR}/lib/logging.sh"
[[ -f "${SCRIPT_DIR}/lib/utils.sh" ]] && source "${SCRIPT_DIR}/lib/utils.sh"

setup_nginx() {
    local domain="$1"
    local port="$2"
    local use_ssl="$3"
    local ssl_email="$4"

    log_info "Configurando Nginx para o domínio: $domain"

    # 1. Garantir que Nginx está instalado
    if ! command -v nginx &> /dev/null; then
        log_info "Nginx não instalado. Instalando..."
        apt-get update -qq && apt-get install -y nginx
    fi

    # 2. Pré-check da configuração atual do Nginx
    nginx -t &> /dev/null || {
        log_error "Configuração atual do Nginx é inválida. Corrija-a antes de continuar."
        return 1
    }

    local config_name=$(echo "$domain" | sed 's/\./-/g')
    local config_file="/etc/nginx/sites-available/mautic-$config_name"
    local enabled_file="/etc/nginx/sites-enabled/mautic-$config_name"

    # 3. Criar configuração HTTP
    cat > "$config_file" <<EOF
server {
    listen 80;
    server_name $domain;

    # Mautic requer limites de upload maiores
    client_max_body_size 50M;

    location / {
        proxy_pass http://localhost:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 600;
        proxy_send_timeout 600;
        proxy_read_timeout 600;
        send_timeout 600;
    }
}
EOF

    ln -sf "$config_file" "$enabled_file"

    # 4. Testar e Recarregar Nginx (HTTP base)
    if nginx -t &> /dev/null; then
        systemctl reload nginx
        log_success "Configuração Nginx (HTTP) ativada para $domain"
    else
        log_error "Erro ao criar configuração Nginx. Removendo arquivo temporário."
        rm -f "$config_file" "$enabled_file"
        return 1
    fi

    # 5. Configurar SSL se solicitado
    if [[ "$use_ssl" =~ ^[SsYy]$ ]]; then
        log_info "Solicitando certificado SSL via Certbot..."
        
        if ! command -v certbot &> /dev/null; then
            apt-get install -y certbot python3-certbot-nginx
        fi

        if certbot --nginx -d "$domain" --non-interactive --agree-tos --email "$ssl_email" --redirect; then
            log_success "Certificado SSL configurado com sucesso para $domain"
        else
            log_warning "Falha ao configurar SSL. O domínio continuará acessível via HTTP."
            log_warning "Verifique DNS e conectividade nas portas 80/443."
        fi
    fi

    return 0
}

# Se executado diretamente (precisa de args)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Uso: $0 <dominio> <porta> [use_ssl] [email]"
        exit 1
    fi
    setup_nginx "$1" "$2" "${3:-n}" "${4:-admin@example.com}"
fi
