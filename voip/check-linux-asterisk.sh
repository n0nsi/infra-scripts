#!/bin/bash

ASTERISK_CONF_DIR="${ASTERISK_CONF_DIR:-/etc/asterisk}"

print_banner() {
    [ "${NO_BANNER:-0}" = "1" ] && return 0

    if [ -t 1 ] && command -v clear >/dev/null 2>&1; then
        clear
    fi

    printf '\033[1;32m╔════════════════════════════════════════════╗\033[0m\n'
    printf '\033[1;32m║       TOOLBOX - By Murilo Prestes          ║\033[0m\n'
    printf '\033[1;32m║     GitHub: https://github.com/n0nsi       ║\033[0m\n'
    printf '\033[1;32m╚════════════════════════════════════════════╝\033[0m\n'
}

print_routes() {
    ip route 2>/dev/null | awk '
        {
            destination=$1
            via="-"
            interface="-"

            for (i=2; i<=NF; i++) {
                if ($i == "via" && i < NF) {
                    via=$(i+1)
                }
                if ($i == "dev" && i < NF) {
                    interface=$(i+1)
                }
            }

            printf "Destino: %s | Via: %s | Interface: %s\n", destination, via, interface
        }
    '
}

print_asterisk_setting() {
    local pattern="$1"
    local found=0
    local file

    shopt -s nullglob
    for file in "$ASTERISK_CONF_DIR"/*.conf; do
        if grep -hE "$pattern" "$file" 2>/dev/null; then
            found=1
        fi
    done
    shopt -u nullglob

    [ "$found" -eq 1 ] || echo "Não encontrado."
}

main() {
    print_banner

    printf '\033[1;32m\n======== [ INFORMAÇÕES DO SISTEMA ] ========\033[0m\n'
    echo
    echo ">> Hostname e SO:"
    LC_ALL=C hostnamectl 2>/dev/null | grep -E 'Static hostname|Operating System|Kernel|Architecture' || true

    echo
    echo ">> Data e Uptime:"
    printf 'Data: '; date
    printf 'Uptime: '; uptime -p 2>/dev/null || uptime

    echo
    echo ">> CPU:"
    LC_ALL=C lscpu 2>/dev/null | grep -E '^Vendor ID:|^Model name:' || true

    echo
    echo ">> Memória (RAM):"
    free -h

    echo
    echo ">> Disco (Partições):"
    df -h --output=source,size,used,avail,target -x tmpfs -x devtmpfs | grep -vE '^Filesystem|tmpfs|udev'

    echo
    echo ">> Espaço total em disco:"
    df -BM --total -x tmpfs -x devtmpfs | awk '/total/ {
        printf "Total: %.2f GB\n", $2/1024
        printf "Usado: %.2f GB\n", $3/1024
        printf "Disponível: %.2f GB\n", $4/1024
    }'

    printf '\033[1;32m\n======== [ REDE ] ========\033[0m\n'
    echo
    echo ">> IPv4 por interface:"
    ip -br -4 addr show 2>/dev/null || true

    echo
    echo ">> IPv6 por interface:"
    ip -br -6 addr show 2>/dev/null || true

    echo
    echo ">> Rotas:"
    print_routes

    echo
    echo ">> DNS configurado:"
    awk '
        $1 == "nameserver" {
            i++
            printf "DNS %-2d: %s\n", i, $2
        }
    ' /etc/resolv.conf 2>/dev/null

    printf '\033[1;32m\n======== [ SETUP DE REDE NO ASTERISK ] ========\033[0m\n'
    echo
    echo ">> IP externo configurado no Asterisk:"
    print_asterisk_setting '^[[:space:]]*externip[[:space:]]*='

    echo
    echo ">> Localnets configurados no Asterisk:"
    print_asterisk_setting '^[[:space:]]*localnet[[:space:]]*='

    echo
    echo ">> IP externo atual (saída para internet):"
    if ! wget --timeout=5 --tries=1 -q -O - https://ipinfo.io/ip 2>/dev/null; then
        echo "Não foi possível consultar o IP externo."
    fi
    echo

    printf '\033[1;32m\n======== [ FIM DO RELATÓRIO ] ========\033[0m\n'
}

main "$@"
