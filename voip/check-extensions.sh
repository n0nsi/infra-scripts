#!/bin/bash

print_banner() {
    printf '\033[1;32m╔════════════════════════════════════════════╗\033[0m\n'
    printf '\033[1;32m║       TOOLBOX - By Murilo Prestes          ║\033[0m\n'
    printf '\033[1;32m║     GitHub: https://github.com/n0nsi       ║\033[0m\n'
    printf '\033[1;32m╚════════════════════════════════════════════╝\033[0m\n'
}

extract_json_field() {
    local line="$1"
    local field="$2"

    printf '%s\n' "$line" | sed -nE "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\\1/p"
}

main() {
    local output line via_addr endpoint user_agent
    local num_ramais=0

    print_banner

    if ! output=$(asterisk -rx 'database show' 2>/dev/null); then
        echo "Erro: não foi possível consultar o database do Asterisk." >&2
        return 1
    fi

    while IFS= read -r line; do
        [[ "$line" == *'user_agent'* ]] || continue

        via_addr=$(extract_json_field "$line" "via_addr")
        endpoint=$(extract_json_field "$line" "endpoint")
        user_agent=$(extract_json_field "$line" "user_agent")

        [ -n "$endpoint" ] || continue
        ((num_ramais++))

        echo "Ramal: $endpoint"
        echo "IP de Registro: ${via_addr:-não informado}"
        echo "Dispositivo de Registro: ${user_agent:-não informado}"
        echo "--------------------------------------------------------------"
    done <<< "$output"

    echo "Total de Ramais: $num_ramais"
}

main "$@"
