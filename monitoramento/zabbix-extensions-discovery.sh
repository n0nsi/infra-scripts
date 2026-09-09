#!/bin/bash

# Gera descoberta de peers SIP em JSON para Zabbix.
# O comando `sip show peers` não informa o User-Agent do aparelho; por isso
# {#DEVICE} fica como UNKNOWN em vez de usar uma coluna incorreta como dispositivo.

main() {
    local output

    if ! output=$(asterisk -rx "sip show peers" 2>/dev/null); then
        echo "Falha ao consultar peers SIP no Asterisk" >&2
        return 1
    fi

    printf '%s\n' "$output" | awk '
        function json_escape(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/\"/, "\\\"", value)
            return value
        }

        BEGIN {
            print "{\n  \"data\":["
            first = 1
        }

        $1 ~ /^[0-9]+(\/[0-9]+)?$/ {
            ext=$1
            sub(/\/.*/, "", ext)
            ip="null"

            for (i=1; i<=NF; i++) {
                if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                    ip=$i
                    break
                }
            }

            ext=json_escape(ext)
            ip=json_escape(ip)

            if (!first) {
                print ","
            }
            first = 0

            printf "    { \"{#EXTEN}\":\"%s\", \"{#IP}\":\"%s\", \"{#DEVICE}\":\"UNKNOWN\" }", ext, ip
        }

        END {
            print "\n  ]\n}"
        }
    '
}

main "$@"
