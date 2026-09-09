#!/bin/bash

LOG_FILE="${LOG_FILE:-/var/log/net-troubleshoot.log}"
INTERFACE=""
RUN_FULL=false
ONLY_DNS=false
failures=0

show_help() {
    cat <<'EOF'
Modo de uso: ./check-network.sh [opções]

Opções:
  --full               Roda todos os testes
  --interface=eth0     Define a interface de rede para diagnóstico
  --dns-only           Executa apenas testes de DNS
  --help               Mostra esta ajuda

Por padrão o log é gravado em /var/log/net-troubleshoot.log.
Use LOG_FILE=/outro/caminho para mudar o arquivo de log.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --full) RUN_FULL=true ;;
        --dns-only) ONLY_DNS=true ;;
        --interface=*) INTERFACE="${arg#*=}" ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            printf 'Argumento desconhecido: %s\nUse --help para ajuda.\n' "$arg" >&2
            exit 2
            ;;
    esac
done

log_dir=$(dirname "$LOG_FILE")
if ! mkdir -p "$log_dir" 2>/dev/null || ! touch "$LOG_FILE" 2>/dev/null; then
    printf 'Não foi possível gravar em %s. Use sudo ou defina LOG_FILE.\n' "$LOG_FILE" >&2
    exit 1
fi

log_info()    { printf '[INFO] %s\n' "$1" | tee -a "$LOG_FILE"; }
log_erro()    { printf '[ERRO] %s\n' "$1" | tee -a "$LOG_FILE" >&2; }
log_sucesso() { printf '[SUCESSO] %s\n' "$1" | tee -a "$LOG_FILE"; }

run_logged() {
    local description="$1"
    shift

    if "$@" >> "$LOG_FILE" 2>&1; then
        log_sucesso "$description"
        return 0
    fi

    log_erro "$description"
    failures=$((failures + 1))
    return 1
}

detect_interface() {
    ip route show default 2>/dev/null | awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i == "dev" && (i + 1) <= NF) {
                    print $(i + 1)
                    exit
                }
            }
        }
    '
}

ensure_interface() {
    if [ -z "$INTERFACE" ]; then
        INTERFACE=$(detect_interface)
    fi

    if [ -z "$INTERFACE" ]; then
        log_erro "Não foi possível identificar uma interface padrão. Use --interface=<nome>."
        return 1
    fi

    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
        log_erro "Interface não encontrada: $INTERFACE"
        return 1
    fi
}

show_resolver_config() {
    log_info "Conteúdo de /etc/resolv.conf"
    tee -a "$LOG_FILE" < /etc/resolv.conf
}

run_dns_checks() {
    log_info "Executando testes de DNS"
    show_resolver_config
    run_logged "Consulta DNS com dig OK" dig google.com +short || true
    run_logged "Consulta DNS com host OK" host google.com || true
}

run_ping_checks() {
    log_info "Executando testes de conectividade"
    run_logged "Ping para 8.8.8.8 OK" ping -c 4 8.8.8.8 || true
    run_logged "Ping com resolução de nome OK" ping -c 4 google.com || true

    if ping -M do -s 1472 -c 2 8.8.8.8 >> "$LOG_FILE" 2>&1; then
        log_sucesso "Teste IPv4 DF com payload de 1472 bytes passou"
    else
        log_erro "Teste IPv4 DF com payload de 1472 bytes falhou; isso sozinho não prova MTU incorreta"
        failures=$((failures + 1))
    fi
}

if [ "$ONLY_DNS" = true ]; then
    run_dns_checks
    [ "$failures" -eq 0 ]
    exit $?
fi

if [ "$RUN_FULL" = true ]; then
    if ! ensure_interface; then
        exit 1
    fi

    log_info "Executando diagnóstico completo na interface $INTERFACE"
    run_logged "Endereços da interface coletados" ip address show "$INTERFACE" || true
    run_logged "Rotas coletadas" ip route || true
    run_logged "Informações do ethtool coletadas" ethtool "$INTERFACE" || true
    run_logged "Estatísticas da interface coletadas" ip -s link show "$INTERFACE" || true
    run_dns_checks
    run_ping_checks

    [ "$failures" -eq 0 ]
    exit $?
fi

if [ -z "$INTERFACE" ]; then
    INTERFACE=$(detect_interface)
fi

log_info "Modo interativo iniciado"
select opt in "IP e Gateway" "Interface" "DNS" "Ping" "Sair"; do
    case "$opt" in
        "IP e Gateway")
            if ensure_interface; then
                log_info "Endereços da interface $INTERFACE"
                ip address show "$INTERFACE" | tee -a "$LOG_FILE"
                log_info "Rotas"
                ip route | tee -a "$LOG_FILE"
            fi
            ;;
        "Interface")
            if ensure_interface; then
                log_info "Dados da interface $INTERFACE"
                ethtool "$INTERFACE" | tee -a "$LOG_FILE"
                ip -s link show "$INTERFACE" | tee -a "$LOG_FILE"
            fi
            ;;
        "DNS")
            run_dns_checks
            ;;
        "Ping")
            run_ping_checks
            ;;
        "Sair")
            log_info "Encerrando..."
            exit 0
            ;;
        *)
            log_erro "Opção inválida"
            ;;
    esac
done
