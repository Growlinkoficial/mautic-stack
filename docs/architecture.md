# Arquitetura do Stack

## Visão Geral

```
                    ┌─────────────────────────────────────────────┐
                    │              Ubuntu 24.04 LTS                │
                    │                                              │
  Browser/Client    │  ┌──────────┐    ┌──────────────────────┐   │
  ───────────────►  │  │  Nginx   │───►│   mautic (Apache)    │   │
  HTTPS:443         │  │ (host)   │    │  mautic-custom:5     │   │
  HTTP:80 (→443)    │  └──────────┘    └──────────┬───────────┘   │
                    │                             │               │
                    │                    ┌────────┴───────────┐   │
                    │                    │  mautic_worker     │   │
                    │                    │  (fila assíncrona) │   │
                    │                    └────────┬───────────┘   │
                    │                             │               │
                    │              ┌──────────────┼──────────┐    │
                    │              │              │          │    │
                    │         ┌───▼───┐      ┌───▼───┐      │    │
                    │         │ MySQL │      │ Redis │      │    │
                    │         │  8.0  │      │7-alpine│      │    │
                    │         └───────┘      └───────┘      │    │
                    │              mautic_net (bridge)        │    │
                    └─────────────────────────────────────────────┘
```

---

## Por que 4 containers?

### `mautic` (web)
O servidor web principal com Apache. Serve o painel, processa requests HTTP síncronos (login, formulários, edição de campanhas). Usa a imagem customizada `mautic-custom:5-apache`.

### `mautic_worker`
O mesmo código Mautic, mas rodando apenas como consumidor de filas do **Symfony Messenger**. Processa envios de e-mail, hits de tracking e broadcasts de forma assíncrona. É **separado do web** por um motivo: enviar 100.000 e-mails não pode travar a interface.

> O worker monta `mautic_data` como **read-only** — ele nunca deve escrever assets. Isso previne corrupção do volume se o worker travar.

### `mysql`
Banco de dados relacional. Armazena contatos, campanhas, configurações, histórico de envios. Usa `utf8mb4` para suporte completo a Unicode e emoji.

### `redis`
Cache de sessões e dados intermediários. Reduz a carga no MySQL em operações repetitivas (ex: verificar segmentos para cada contact lookup). Requer autenticação obrigatória.

---

## Por que um `Dockerfile` customizado?

A imagem `mautic/mautic:5-apache` foi compilada com suporte a **AVIF** na extensão PHP `gd`, mas a dependência `libavif15` não está presente no Debian base da imagem. Resultado: `gd` falha ao carregar, quebrando geração de imagens, thumbnails e captchas.

O `Dockerfile` deste projeto resolve isso adicionando apenas a dependência faltante, sem alterar entrypoint ou configurações da imagem:

```dockerfile
FROM mautic/mautic:5-apache
USER root
RUN apt-get update && apt-get install -y --no-install-recommends libavif15 \
    && rm -rf /var/lib/apt/lists/*
USER www-data
```

---

## SSL Termination via Nginx

O Nginx roda no **host** (não em container) e faz proxy reverso para o Mautic na porta `8080`. O fluxo de SSL:

```
Browser → Nginx (443, SSL termination) → Mautic container (80, HTTP)
```

Para o Mautic saber que a conexão original era HTTPS, são necessários **dois mecanismos em conjunto**:

**1 — `local.php`: trusted_proxies**
```php
'trusted_proxies' => ['0.0.0.0/0'],
```
Diz ao Symfony para confiar nos headers `X-Forwarded-*` do Nginx.

**2 — `config/apache-proxy.conf`: SetEnvIf**
```apache
SetEnvIf X-Forwarded-Proto "^https$" HTTPS=on
SetEnvIf X-Forwarded-Proto "^https$" REQUEST_SCHEME=https
```
Garante que o Apache repasse `HTTPS=on` ao PHP, que usa essa variável para montar URLs absolutas. Sem isso, o Mautic gera URLs `http://` mesmo quando o usuário acessa `https://`, causando redirect loop infinito.

**3 — Nginx: header hardcoded**
```nginx
proxy_set_header X-Forwarded-Proto https;  # Sempre https, nunca $scheme
```
Usar `$scheme` no bloco 443 funcionaria, mas requer cuidado extra. `https` hardcoded é mais seguro.

---

## Symfony Messenger (Filas Assíncronas)

O Mautic 5 usa o **Symfony Messenger** para processamento assíncrono. As mensagens ficam na tabela `messenger_messages` do MySQL (transport `doctrine://default`) e o worker as consome continuamente.

```
mautic_web ──► messenger_messages (MySQL) ──► mautic_worker
              (enfileira)                    (processa)
```

O worker usa `--time-limit=300` (reinicia a cada 5 min) e `--memory-limit=256M` (unidade obrigatória — sem a letra `M`, o Symfony interpreta como bytes).

---

## Volumes

| Volume | Montagem | Modo | Descrição |
|--------|----------|------|-----------|
| `mautic_data` | `/var/www/html` | `rw` no web, `ro` no worker | Assets, media, código PHP |
| `mysql_data` | `/var/lib/mysql` | `rw` | Dados do banco |
| `redis_data` | `/data` | `rw` | Persistência do cache |
| `./config/local.php` | `/var/www/html/app/config/local.php` | bind mount | Config do Mautic |
| `./config/php.ini` | `/usr/local/etc/php/conf.d/` | bind mount | Config do PHP |
| `./config/apache-proxy.conf` | `/etc/apache2/conf-enabled/` | bind mount, `ro` | Fix SSL termination |

---

## Relacionado

- **Instalação**: [`docs/installation.md`](installation.md)
- **Operações**: [`docs/operations.md`](operations.md)
- **Erros conhecidos**: [`docs/troubleshooting.md`](troubleshooting.md)
