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

    # 2. Limpar configuração anterior (idempotência)
    local config_name=$(echo "$domain" | sed 's/\./-/g')
    local config_file="/etc/nginx/sites-available/mautic-$config_name"
    local enabled_file="/etc/nginx/sites-enabled/mautic-$config_name"
    rm -f "$config_file" "$enabled_file"

    # 3. Criar configuração HTTP-only com proxy
    # NOTA: bloco 443 NÃO incluído aqui — nginx -t falharia sem ssl_certificate.
    # O Certbot adiciona o bloco 443 automaticamente em seguida.
    cat > "$config_file" <<EOF
server {
    listen 80;
    server_name $domain;

    # Mautic requer limites de upload maiores
    client_max_body_size 50M;

    location / {
        proxy_pass http://localhost:$port;
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 600;
        proxy_send_timeout    600;
        proxy_read_timeout    600;
        send_timeout          600;
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
        nginx -t  # exibir erro real
        rm -f "$config_file" "$enabled_file"
        return 1
    fi

    # 5. Configurar SSL via Certbot
    if [[ "$use_ssl" =~ ^[SsYy]$ ]]; then
        if [[ "$ssl_email" == "admin@example.com" || -z "$ssl_email" ]]; then
            log_warning "Email inválido para SSL. Altere SSL_EMAIL no .env e execute novamente."
            return 0
        fi

        log_info "Solicitando certificado SSL via Certbot..."

        if ! command -v certbot &> /dev/null; then
            apt-get install -y certbot python3-certbot-nginx
        fi

        # Certbot --nginx reescreve o config e adiciona o bloco 443 com os certificados
        if certbot --nginx -d "$domain" --non-interactive --agree-tos --email "$ssl_email" --redirect; then
            log_success "Certificado SSL configurado com sucesso para $domain"

            # 6. Patch pós-Certbot: forçar X-Forwarded-Proto https no bloco 443
            # Sem isso o Mautic recebe scheme=http e entra em redirect loop infinito
            sed -i 's|proxy_set_header X-Forwarded-Proto \$scheme;|proxy_set_header X-Forwarded-Proto https; # hardcoded-ssl|g' "$config_file"

            if nginx -t &> /dev/null; then
                systemctl reload nginx
                log_success "X-Forwarded-Proto corrigido para https (anti redirect-loop Mautic)"
            else
                log_warning "nginx -t falhou após patch. Verifique $config_file"
            fi
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
    setup_nginx "$1" "$2" "${3:-n}" "${4:-}"
fi
