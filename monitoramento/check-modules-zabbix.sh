#!/bin/bash

LOG_FILE="${LOG_FILE:-/var/log/check-modules-zabbix.log}"
FWCONSOLE_BIN="${FWCONSOLE_BIN:-/var/lib/asterisk/bin/fwconsole}"
ASTERISK_USER="${ASTERISK_USER:-asterisk}"

log_problem() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null && touch "$LOG_FILE" 2>/dev/null; then
        printf '%s [PROBLEM] %s\n' "$timestamp" "$message" >> "$LOG_FILE"
    fi
}

run_fwconsole() {
    sudo -u "$ASTERISK_USER" "$FWCONSOLE_BIN" ma list
}

main() {
    local output disabled_modules

    if ! output=$(run_fwconsole 2>&1); then
        log_problem "Não foi possível consultar os módulos do FreePBX"
        echo "PROBLEM"
        return 0
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

    if [ -n "$disabled_modules" ]; then
        while IFS='|' read -r name status; do
            [ -n "$name" ] || continue
            log_problem "Módulo com problema detectado: $name, $status"
        done <<< "$disabled_modules"
        echo "PROBLEM"
    else
        echo "OK"
    fi
}

main "$@"
