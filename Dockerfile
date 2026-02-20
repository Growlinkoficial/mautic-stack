# ==============================================================================
# Mautic 5 — Custom Image
# Baseado em mautic/mautic:5-apache com dependências adicionais.
#
# Problema resolvido:
# ERR-20260220-libavif: A imagem base foi compilada com suporte a libavif,
# mas libavif15 não está presente no Debian base, impedindo a extensão gd
# de carregar e causando warnings ao iniciar PHP.
# ==============================================================================
FROM mautic/mautic:5-apache

# Instalar libavif como root antes de iniciar como www-data
USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends libavif15 && \
    rm -rf /var/lib/apt/lists/*

# Retornar ao usuário padrão da imagem
USER www-data
