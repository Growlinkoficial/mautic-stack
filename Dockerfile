# ==============================================================================
# Mautic 5 — Custom Image
# Baseado em mautic/mautic:5-apache com dependências adicionais.
#
# Problemas resolvidos:
# ERR-20260220-015: libavif15 ausente no Debian base → gd não carregava
# ERR-20260220-019: libXpm.so.4 ausente → gd falhava em startup com warning
# ==============================================================================
FROM mautic/mautic:5-apache

# Instalar dependências da extensão gd como root
USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libavif15 \
    libxpm4 \
    libwebp7 \
    libjpeg62-turbo && \
    rm -rf /var/lib/apt/lists/*

# Retornar ao usuário padrão da imagem
USER www-data
