#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

print_banner() {
    printf '\033[1;32m╔════════════════════════════════════════════╗\033[0m\n'
    printf '\033[1;32m║       TOOLBOX - By Murilo Prestes          ║\033[0m\n'
    printf '\033[1;32m║     GitHub: https://github.com/n0nsi       ║\033[0m\n'
    printf '\033[1;32m╚════════════════════════════════════════════╝\033[0m\n'
}

run_check() {
    local script="$1"

    if [ ! -f "$script" ]; then
        echo "Erro: script necessário não encontrado: $script" >&2
        return 1
    fi

    NO_BANNER=1 bash "$script"
}

main() {
    local status=0

    print_banner

    run_check "$SCRIPT_DIR/check-linux-asterisk.sh" || status=1

    echo
    printf '\033[1;32m======== [ VERIFICAÇÃO DOS MÓDULOS DO FREEPBX ] ========\033[0m\n'
    run_check "$SCRIPT_DIR/check-freepbx-modules.sh" || status=1

    return "$status"
}

main "$@"
