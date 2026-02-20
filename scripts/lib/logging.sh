#!/bin/bash

# Source guard para evitar carregamento duplo e erros de readonly
if [ -n "${_LIB_LOGGING_SH_LOADED:-}" ]; then return; fi
_LIB_LOGGING_SH_LOADED="true"

# Carregar cores se disponíveis
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${LIB_DIR}/colors.sh" ]] && source "${LIB_DIR}/colors.sh"

# Variáveis globais de log (não readonly para permitir flexibilidade se necessário)
LOG_DIR="/var/log/mautic-stack"
LOG_FILE="${LOG_DIR}/install_$(date +%Y%m%d).log"

# Garantir que o diretório de log existe (silencioso)
mkdir -p "$LOG_DIR" 2>/dev/null || true

log_info() {
    local msg="$*"
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${msg}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] - ${msg}" >> "$LOG_FILE" 2>/dev/null || true
}

log_success() {
    local msg="$*"
    echo -e "${GREEN}[SUCESSO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${msg}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCESSO] - ${msg}" >> "$LOG_FILE" 2>/dev/null || true
}

log_warning() {
    local msg="$*"
    echo -e "${YELLOW}[AVISO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${msg}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [AVISO] - ${msg}" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    local msg="$*"
    echo -e "${RED}[ERRO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${msg}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERRO] - ${msg}" >> "$LOG_FILE" 2>/dev/null || true
}
