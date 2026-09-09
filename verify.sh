#!/bin/bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
errors=0

ok() {
    printf '[OK]   %s\n' "$1"
}

error() {
    printf '[ERR]  %s\n' "$1" >&2
    errors=$((errors + 1))
}

check_file() {
    local path="$1"

    if [ -f "$path" ]; then
        ok "${path#"$ROOT_DIR"/}"
    else
        error "arquivo ausente: ${path#"$ROOT_DIR"/}"
    fi
}

check_executable() {
    local path="$1"

    if [ -x "$path" ]; then
        ok "executable: ${path#"$ROOT_DIR"/}"
    else
        error "não executável: ${path#"$ROOT_DIR"/}"
    fi
}

check_syntax() {
    local shell_name="$1"
    local path="$2"

    if "$shell_name" -n "$path"; then
        ok "syntax: ${path#"$ROOT_DIR"/}"
    else
        error "syntax: ${path#"$ROOT_DIR"/}"
    fi
}

main() {
    local path
    local -a sh_scripts=(
        "$ROOT_DIR/backup/daily-backup.sh"
        "$ROOT_DIR/backup/manual-backup.sh"
    )
    local -a bash_scripts=(
        "$ROOT_DIR/network/check-network.sh"
        "$ROOT_DIR/monitoramento/check-modules-zabbix.sh"
        "$ROOT_DIR/monitoramento/zabbix-extensions-discovery.sh"
        "$ROOT_DIR/voip/check-extensions.sh"
        "$ROOT_DIR/voip/check-freepbx-modules.sh"
        "$ROOT_DIR/voip/check-linux-asterisk.sh"
        "$ROOT_DIR/voip/check-queues.sh"
        "$ROOT_DIR/voip/check-voip.sh"
    )
    local -a test_scripts=(
        "$ROOT_DIR/tests/run-tests.sh"
        "$ROOT_DIR/tests/review-regressions.sh"
    )

    check_file "$ROOT_DIR/README.md"
    check_file "$ROOT_DIR/LICENSE"

    for path in "${sh_scripts[@]}" "${bash_scripts[@]}" "${test_scripts[@]}"; do
        check_file "$path"
    done

    echo
    echo "File modes"
    for path in "${sh_scripts[@]}" "${bash_scripts[@]}"; do
        check_executable "$path"
    done

    echo
    echo "Syntax"

    for path in "${sh_scripts[@]}"; do
        check_syntax sh "$path"
    done

    for path in "${bash_scripts[@]}" "${test_scripts[@]}"; do
        check_syntax bash "$path"
    done

    echo
    if [ "$errors" -eq 0 ]; then
        ok "repository checks passed"
        return 0
    fi

    printf '[ERR]  %d check(s) need attention\n' "$errors" >&2
    return 1
}

main "$@"
