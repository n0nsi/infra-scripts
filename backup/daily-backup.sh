#!/usr/bin/env sh

#---> Mostra o pai da criança:
#╔════════════════════════════════════════════╗
#║       TOOLBOX - By Murilo Prestes          ║
#║     GitHub: https://github.com/n0nsi       ║
#╚════════════════════════════════════════════╝

# === CONFIGURAÇÕES ===
backup_path="/seu/diretorio"
external_storage="/mnt/backup"
log_file="/var/log/daily-backup.log"
date_format=$(date "+%Y-%m-%d_%H-%M")
final_archive="backup-$date_format.tar.gz"

# === GARANTE QUE O DIRETÓRIO DE LOG EXISTA ===
mkdir -p "$(dirname "$log_file")"

# === VERIFICA SE O DIRETÓRIO DE BACKUP EXISTE ===
if [ ! -d "$backup_path" ]; then
  echo "$(date "+%Y-%m-%d %H:%M:%S") [ERRO] Diretório de backup não encontrado: $backup_path" >> "$log_file"
  exit 1
fi

# === VERIFICA SE O DISPOSITIVO EXTERNO ESTÁ MONTADO ===
if ! mountpoint -q "$external_storage"; then
  echo "$(date "+%Y-%m-%d %H:%M:%S") [ERRO] Dispositivo não montado em: $external_storage" >> "$log_file"
  exit 1
fi

# === INÍCIO DO BACKUP ===
echo "$(date "+%Y-%m-%d %H:%M:%S") [INFO] Iniciando backup para $external_storage/$final_archive" >> "$log_file"

if tar -czPf "$external_storage/$final_archive" "$backup_path" >> "$log_file" 2>&1; then
  echo "$(date "+%Y-%m-%d %H:%M:%S") [SUCESSO] Backup concluído com sucesso." >> "$log_file"
else
  echo "$(date "+%Y-%m-%d %H:%M:%S") [ERRO] Falha ao executar backup!" >> "$log_file"
  exit 1
fi
