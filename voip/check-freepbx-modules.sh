#!/bin/bash

LOG_FILE="${LOG_FILE:-/var/log/check-modules-freepbx.log}"
FWCONSOLE_BIN="${FWCONSOLE_BIN:-fwconsole}"

print_banner() {
    [ "${NO_BANNER:-0}" = "1" ] && return 0
    printf '\033[1;32m╔════════════════════════════════════════════╗\033[0m\n'
    printf '\033[1;32m║       TOOLBOX - By Murilo Prestes          ║\033[0m\n'
    printf '\033[1;32m║     GitHub: https://github.com/n0nsi       ║\033[0m\n'
    printf '\033[1;32m╚════════════════════════════════════════════╝\033[0m\n'
}

write_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null && touch "$LOG_FILE" 2>/dev/null; then
        printf '%s [%s] %s\n' "$timestamp" "$level" "$message" >> "$LOG_FILE"
    fi
}

main() {
    local output disabled_modules

    print_banner
    echo "Checando todos os módulos do FreePBX..."

    if ! output=$("$FWCONSOLE_BIN" ma list 2>&1); then
        echo "Erro: não foi possível consultar os módulos do FreePBX." >&2
        write_log "ERROR" "Falha ao executar fwconsole ma list"
        return 1
    fi

    disabled_modules=$(printf '%s\n' "$output" | awk -F'|' '
        {
            name=$2
            status=$4
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)

            status_lower=tolower(status)
            if (name != "" && (status_lower ~ /disabled/ || status_lower ~ /desabilitado/)) {
                print name "|" status
            }
        }
    ')

    if [ -z "$disabled_modules" ]; then
        echo "Check OK, nenhum módulo desabilitado foi encontrado."
        write_log "SUCCESS" "Nenhum módulo desabilitado encontrado"
        return 0
    fi

    while IFS='|' read -r name status; do
        [ -n "$name" ] || continue
        echo
        echo "Módulo com problema detectado:"
        echo "Módulo: $name"
        echo "Status: $status"
        write_log "PROBLEM" "Módulo com problema detectado: $name, $status"
    done <<< "$disabled_modules"

    return 1
}

main "$@"
