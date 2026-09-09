#!/bin/bash

ASTERISK_BIN="${ASTERISK_BIN:-asterisk}"

print_banner() {
    printf '\033[1;32m╔════════════════════════════════════════════╗\033[0m\n'
    printf '\033[1;32m║       TOOLBOX - By Murilo Prestes          ║\033[0m\n'
    printf '\033[1;32m║     GitHub: https://github.com/n0nsi       ║\033[0m\n'
    printf '\033[1;32m╚════════════════════════════════════════════╝\033[0m\n'
}

list_queue_names() {
    printf '%s\n' "$1" | awk '$2 == "has" {print $1}'
}

print_queue() {
    local queue_name="$1"
    local output strategy member_count=0 member

    if ! output=$("$ASTERISK_BIN" -rx "queue show $queue_name" 2>/dev/null); then
        echo "Erro ao consultar a fila $queue_name." >&2
        return 1
    fi

    if ! printf '%s\n' "$output" | awk -v queue="$queue_name" 'NR == 1 && $1 == queue && $2 == "has" {found=1} END {exit !found}'; then
        echo "Fila não encontrada durante a consulta: $queue_name" >&2
        return 1
    fi

    strategy=$(printf '%s\n' "$output" | sed -nE "1s/.* in '([^']+)' strategy.*/\\1/p")

    echo "N° da Fila: $queue_name"
    echo "Estratégia de Ring: ${strategy:-não informada}"
    echo "Membros:"

    while IFS= read -r member; do
        [ -n "$member" ] || continue
        echo "$member"
        ((member_count++))
    done < <(printf '%s\n' "$output" | sed -nE 's/.*Local\/([^@[:space:]]+)@.*/\1/p')

    if (( member_count == 0 )); then
        echo "Nenhum membro Local/ encontrado."
    fi

    echo "-----------------------------"
}

main() {
    local output queue_names option queue_name status=0

    print_banner

    if ! output=$("$ASTERISK_BIN" -rx 'queue show' 2>/dev/null); then
        echo "Erro: não foi possível consultar as filas do Asterisk." >&2
        return 1
    fi

    queue_names=$(list_queue_names "$output")
    if [ -z "$queue_names" ]; then
        echo "Nenhuma fila encontrada."
        return 0
    fi

    echo "Deseja consultar uma fila específica ou todas as filas?"
    echo "1. Fila específica"
    echo "2. Todas as filas"
    printf 'Escolha uma opção (1/2): '
    IFS= read -r option

    case "$option" in
        1)
            printf 'Digite o número/nome da fila que deseja consultar: '
            IFS= read -r queue_name

            if ! printf '%s\n' "$queue_names" | grep -Fxq -- "$queue_name"; then
                echo "Fila não encontrada: $queue_name" >&2
                return 1
            fi

            print_queue "$queue_name"
            ;;
        2)
            while IFS= read -r queue_name; do
                [ -n "$queue_name" ] || continue
                print_queue "$queue_name" || status=1
            done <<< "$queue_names"
            return "$status"
            ;;
        *)
            echo "Opção inválida." >&2
            return 1
            ;;
    esac
}

main "$@"
