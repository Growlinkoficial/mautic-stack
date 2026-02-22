# Troubleshooting

Formato: **Sintoma → Causa → Solução**. Para histórico completo de erros, veja [`.learnings/ERRORS.md`](../.learnings/ERRORS.md).

---

## 🔴 Erros Críticos

### `ERR_TOO_MANY_REDIRECTS` — Loop de redirect infinito

**Causa**: Mautic não consegue identificar o protocolo HTTPS porque `trusted_proxies` está ausente no `local.php` ou o Apache não repassa `HTTPS=on` ao PHP.

**Solução**:
```bash
# 1. Verificar se local.php tem trusted_proxies
grep 'trusted_proxies' /home/mautic-stack/config/local.php

# 2. Verificar se o apache-proxy.conf está montado
docker compose exec mautic cat /etc/apache2/conf-enabled/proxy-ssl.conf

# 3. Recriar o container com as configurações corretas
docker compose up -d --force-recreate mautic
```

> Referências: ERR-20260220-010, LRN-20260220-008

---

**Causa**: O bloco `environment:` do serviço `mautic`, `mautic_worker` ou `mautic_cron` no `docker-compose.yml` está incompleto. A imagem `mautic/mautic:5-apache` exige variáveis com prefixo `MAUTIC_DB_*`, não `MYSQL_*`.

**Solução**: Verificar `docker-compose.yml` — os serviços devem ter:
```yaml
DOCKER_MAUTIC_ROLE: mautic_web   # ou mautic_worker ou mautic_cron
MAUTIC_DB_HOST: mysql
MAUTIC_DB_NAME: ${MYSQL_DATABASE}
MAUTIC_DB_USER: ${MYSQL_USER}
MAUTIC_DB_PASSWORD: ${MYSQL_PASSWORD}
```

> Referência: ERR-20260220-008, LRN-20260220-006

---

### `local.php` corrompido — `$parameters` apagado

**Causa**: `envsubst` sem lista explícita de variáveis substitui `$parameters` do PHP por string vazia.

**Diagnóstico**:
```bash
grep '\$parameters' /home/mautic-stack/config/local.php || echo "ARQUIVO CORROMPIDO"
```

**Solução**: Regenerar `local.php`:
```bash
rm /home/mautic-stack/config/local.php
sudo ./install.sh  # Regenera o arquivo corretamente
```

> Referência: ERR-20260220-011, LRN-20260220-009

---

## 🟡 Erros de Média Gravidade

### `Permission denied` ao trocar idioma (pt_BR)

**Causa**: O diretório `var/cache` não tem permissão de escrita para `www-data`.

**Solução**:
```bash
docker compose exec mautic chown -R www-data:www-data /var/www/html
docker compose exec mautic chmod -R 775 /var/www/html/var/cache
docker compose exec mautic chmod -R 775 /var/www/html/var/logs
```

> Referência: ERR-20260220-014

---

### `Unable to load dynamic library 'gd'` (libavif)

**Causa**: A imagem base foi compilada com suporte a `libavif`, mas `libavif15` não está no Debian.

**Solução**: Reconstruir a imagem customizada:
```bash
docker compose build
docker compose up -d --force-recreate mautic mautic_worker mautic_cron
```

> Referência: ERR-20260220-015

---

### Idioma trocado para pt_BR mas interface não atualizou

**Causa**: O Mautic armazena strings de tradução em cache do Symfony. A mudança só é aplicada em nova sessão.

**Solução**:
```bash
docker compose exec -w /var/www/html mautic php bin/console cache:clear
# Em seguida: logout e login novamente no navegador
```

---

### Redis healthcheck falha / container unhealthy

**Causa**: `REDIS_PASSWORD` não está no bloco `environment:` do serviço Redis.

**Solução**: Verificar `docker-compose.yml`:
```yaml
redis:
  environment:
    - REDIS_PASSWORD=${REDIS_PASSWORD}
```

> Referência: ERR-20260220-006, LRN-20260220-004

---

## 🟠 Erros de Boot / Inicialização

### `Could not open input file: bin/console`

**Causa**: Race condition — o worker iniciou antes do entrypoint da imagem terminar de copiar os arquivos do Mautic para o volume.

**Solução**: Aguardar ~60 segundos e tentar novamente. O `install.sh` tem wait loop automático para isso.

```bash
# Loop manual para aguardar:
until docker compose exec -T mautic test -f /var/www/html/bin/console; do
    echo "Aguardando bin/console..."; sleep 10
done
```

> Referência: LRN-20260220-007

---

### `The "--db-host" option does not exist`

**Causa**: `mautic:install` usa underscores nos parâmetros, não hyphens.

**Correto**: `--db_host`, `--db_name`, `--db_user`, `--db_password`, `--admin_email` etc.

> Referência: ERR-20260220-007

---

### `nginx: [emerg] no ssl_certificate is defined`

**Causa**: Tentativa de incluir bloco `listen 443 ssl` antes do Certbot gerar o certificado.

**Fluxo correto**:
1. Config HTTP-only (porta 80)
2. Certbot gera certificado e cria bloco 443
3. `sed` adiciona `X-Forwarded-Proto https` no bloco gerado

> Referência: ERR-20260220-009

---

## 🟢 Erros Operacionais

### `no configuration file provided: not found`

**Causa**: Comando `docker compose` executado fora do diretório do projeto.

**Solução**:
```bash
cd /home/mautic-stack
docker compose ...
```

---

### `The ACME server believes admin@example.com is an invalid email address`

**Causa**: Email placeholder usado no wizard de SSL.

**Solução**: O wizard atual já bloqueia `@example.com`. Para corrigir manualmente:
```bash
certbot certonly --nginx -d seu.dominio.com --email seu@email.com
```

> Referência: ERR-20260220-002
