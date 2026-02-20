# Backup e Restauração — `backup.sh` / `restore.sh`

## Por que dois scripts separados

**Separação de responsabilidades** — `backup.sh` salva dados, `restore.sh` os recupera. Manter scripts simples e focados reduz o risco de um bug num afetar o outro. A assimetria intencional é: backup roda silenciosamente via cron, restore requer confirmação manual porque sobrescreve dados de produção.

---

## `backup.sh` — O que copia e como

### O que é salvo

| Componente | Arquivo gerado | Conteúdo |
|-----------|---------------|----------|
| Banco de dados | `mysql_backup_YYYYMMDD_HHMMSS.sql` | Dump completo via `mysqldump` |
| Arquivos do Mautic | `mautic_files_YYYYMMDD_HHMMSS.tar.gz` | Volume Docker `mautic_data` inteiro |

Todos os arquivos vão para `backups/` na raiz do projeto.

### Por que backup do volume e não só do banco?

O `mautic_data` contém arquivos de mídia, assets compilados, plugins e segredos que **não vivem no banco**. Restaurar só o SQL levaria a um Mautic funcionando mas sem imagens nem arquivos de campanha.

### Como executar

```bash
# Na pasta /home/mautic-stack:
sudo ./backup.sh
```

### Como agendar (cron)

O `install.sh` configura automaticamente. Para adicionar manualmente:

```bash
# Backup diário às 3h da manhã
0 3 * * * root /home/mautic-stack/backup.sh >> /var/log/mautic-stack/backup.log 2>&1
```

---

## `restore.sh` — Fluxo de restauração

> ⚠️ **Atenção**: a restauração **sobrescreve todos os dados atuais** — banco e arquivos. A operação não é reversível. Faça sempre um backup antes de restaurar.

### Pré-requisitos

- Stack rodando (`docker compose ps` mostra `Up`) — o MySQL precisa estar acessível
- Pelo menos um arquivo `.sql` em `backups/`
- Arquivo `.env` válido na raiz do projeto

### O que o script faz (passo a passo)

```
1. Lê backups disponíveis em backups/
2. Seleciona automaticamente o mais recente
3. Exibe o nome dos arquivos que serão restaurados
4. Pede confirmação explícita (s/n)
5. Para os containers mautic + mautic_worker
6. Restaura o banco MySQL via mysql < arquivo.sql
7. Restaura os arquivos do volume via alpine + tar xzf
8. Reinicia os containers
```

### Como executar

```bash
# Na pasta /home/mautic-stack:
sudo ./restore.sh
```

Saída esperada ao final:
```
[SUCESSO] Restauração concluída com sucesso!
  🌐 URL: https://mkt.suaempresa.com
```

### Após restaurar

```bash
# Limpar o cache do Mautic (obrigatório após restauração)
docker compose exec -w /var/www/html mautic php bin/console cache:clear
```

---

## Estratégia de Retenção

Por padrão, os backups se acumulam em `backups/`. Para limpeza automática:

```bash
# Remover backups com mais de 30 dias
find /home/mautic-stack/backups/ -name "*.sql" -mtime +30 -delete
find /home/mautic-stack/backups/ -name "*.tar.gz" -mtime +30 -delete
```

---

## Relacionado

- **Instalação inicial**: [`docs/installation.md`](installation.md)
- **Erros de restauração**: [`docs/troubleshooting.md`](troubleshooting.md)
- **Configuração de cron**: [`docs/operations.md`](operations.md)
