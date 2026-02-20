# Mautic Stack (v5.2.6 + Redis + Docker)

Script de instalação automatizado para Mautic 5 no Ubuntu 24.04.

## 🚀 Como Usar

1. **Clone ou Copie** os arquivos para o servidor Ubuntu.
2. **Configure o ambiente**:
   ```bash
   cp .env.example .env
   nano .env
   ```
3. **Execute o instalador**:
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```

## 📂 Estrutura do Projeto

- `install.sh`: Script mestre de instalação.
- `uninstall.sh`: Script de remoção completa.
- `backup.sh`: Gerador de backups (DB + Arquivos/Assets).
- `docker-compose.yml`: Definição dos containers.
- `config/`: Templates e configurações (PHP, Mautic).
- `scripts/`: Bibliotecas e scripts auxiliares (preflight, nginx, validate).
- `backups/`: Diretório padrão de saída dos backups.

## 🛠️ Comandos Úteis

- **Logs do Mautic**: `docker compose logs -f mautic`
- **Limpar Cache**: `docker compose exec mautic php bin/console cache:clear`
- **Status do Stack**: `sudo ./scripts/validate.sh`

## ⚖️ Licença
Uso interno Growlink.
