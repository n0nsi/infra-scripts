#!/usr/bin/env sh

printf 'Digite o caminho da pasta a ser salva no backup: '
IFS= read -r backup_path
printf 'Digite o caminho onde o backup será salvo: '
IFS= read -r external_storage

log_file="${LOG_FILE:-/var/log/manual-backup.log}"
timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
final_archive="backup-$timestamp.tar.gz"
archive_path="$external_storage/$final_archive"
partial_archive="$archive_path.partial"

log() {
  level="$1"
  shift
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" >> "$log_file"
}

log_dir=$(dirname "$log_file")
if ! mkdir -p "$log_dir" 2>/dev/null; then
  printf 'Não foi possível criar o diretório de log: %s\n' "$log_dir" >&2
  exit 1
fi

if ! : >> "$log_file" 2>/dev/null; then
  printf 'Não foi possível gravar no log: %s\n' "$log_file" >&2
  exit 1
fi

if [ ! -d "$backup_path" ]; then
  log "ERRO" "Diretório de backup não encontrado: $backup_path"
  exit 1
fi

if ! mountpoint -q "$external_storage"; then
  log "ERRO" "Dispositivo não montado em: $external_storage"
  exit 1
fi

log "INFO" "Iniciando backup para $archive_path"
rm -f "$partial_archive"

# Do not use tar -P here. Relative archive members are safer to restore elsewhere.
if tar -czf "$partial_archive" "$backup_path" >> "$log_file" 2>&1; then
  if mv "$partial_archive" "$archive_path"; then
    log "SUCESSO" "Backup concluído: $archive_path"
    printf 'Backup salvo em: %s\n' "$archive_path"
    exit 0
  fi

  log "ERRO" "Backup criado, mas não foi possível finalizar o arquivo: $archive_path"
else
  log "ERRO" "Falha ao executar backup de: $backup_path"
fi

rm -f "$partial_archive"
exit 1
