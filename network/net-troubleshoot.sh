#!/bin/bash

#---> Mostra o pai da criança:
echo -e "\e[1;32m╔════════════════════════════════════════════╗\e[0m"
echo -e "\e[1;32m║       TOOLBOX - By Murilo Prestes          ║\e[0m"
echo -e "\e[1;32m║     GitHub: https://github.com/n0nsi       ║\e[0m"
echo -e "\e[1;32m╚════════════════════════════════════════════╝\e[0m"

LOG_FILE="/var/log/net-troubleshoot.log"
INTERFACE=""
RUN_FULL=false
ONLY_DNS=false

# Cria o arquivo de log se não existir
touch "$LOG_FILE"

log_info()    { echo -e "[INFO] $1" | tee -a "$LOG_FILE"; }
log_erro()    { echo -e "[ERRO] $1" | tee -a "$LOG_FILE"; }
log_sucesso() { echo -e "[SUCESSO] $1" | tee -a "$LOG_FILE"; }

# Verifica se é root
if [[ $EUID -ne 0 ]]; then
    log_erro "Este script precisa ser executado como root!"
    exit 1
fi

# Leitura de argumentos
for arg in "$@"; do
    case $arg in
        --full) RUN_FULL=true ;;
        --dns-only) ONLY_DNS=true ;;
        --interface=*) INTERFACE="${arg#*=}" ;;
        --help)
            echo -e "\nModo de uso: ./net-troubleshoot.sh [opções]\n
Opções:
  --full               Roda todos os testes
  --interface=eth0     Define a interface de rede para diagnóstico
  --dns-only           Executa apenas testes de DNS
  --help               Mostra esta ajuda
" | tee -a "$LOG_FILE"
            exit 0
            ;;
        *)
            log_erro "Argumento desconhecido: $arg"
            echo "Use --help para ajuda." | tee -a "$LOG_FILE"
            exit 1
            ;;
    esac
done

# Apenas testes de DNS
if [ "$ONLY_DNS" = true ]; then
    log_info "Executando testes de DNS"
    cat /etc/resolv.conf | tee -a "$LOG_FILE"

    dig google.com +short >> "$LOG_FILE" 2>&1 && log_sucesso "Consulta DNS com dig OK" || log_erro "Falha na consulta com dig"
    host google.com >> "$LOG_FILE" 2>&1 && log_sucesso "Consulta DNS com host OK" || log_erro "Falha na consulta com host"
    exit 0
fi

# Testes completos
if [ "$RUN_FULL" = true ]; then
    log_info "Executando diagnóstico completo..."

    log_info "Verificando IP e Gateway"
    ip a show "$INTERFACE" >> "$LOG_FILE" 2>&1 && log_sucesso "IP listado com sucesso" || log_erro "Falha ao listar IP"
    ip r >> "$LOG_FILE" 2>&1 && log_sucesso "Rotas listadas" || log_erro "Falha ao obter rotas"

    log_info "Analisando interface $INTERFACE"
    ethtool "$INTERFACE" >> "$LOG_FILE" 2>&1 && log_sucesso "ethtool OK" || log_erro "Falha no ethtool"
    ip -s link show "$INTERFACE" >> "$LOG_FILE" 2>&1 && log_sucesso "Estatísticas da interface OK" || log_erro "Erro nas estatísticas da interface"

    log_info "Realizando testes de DNS"
    cat /etc/resolv.conf | tee -a "$LOG_FILE"
    dig google.com +short >> "$LOG_FILE" 2>&1 && log_sucesso "dig OK" || log_erro "dig falhou"
    host google.com >> "$LOG_FILE" 2>&1 && log_sucesso "host OK" || log_erro "host falhou"

    log_info "Realizando testes de Ping e MTU"
    ping -c 4 8.8.8.8 >> "$LOG_FILE" 2>&1 && log_sucesso "Ping 8.8.8.8 OK" || log_erro "Ping 8.8.8.8 falhou"
    ping -c 4 google.com >> "$LOG_FILE" 2>&1 && log_sucesso "Ping google.com OK" || log_erro "Ping google.com falhou"
    ping -M do -s 1472 -c 2 8.8.8.8 >> "$LOG_FILE" 2>&1 && log_sucesso "MTU correta" || log_erro "Problema com MTU"

    exit 0
fi

# Modo interativo
log_info "Modo interativo iniciado"
select opt in "IP e Gateway" "Interface" "DNS" "Ping" "Sair"; do
    case "$opt" in
        "IP e Gateway")
            log_info "Exibindo IP e Gateway"
            ip a show "$INTERFACE" | tee -a "$LOG_FILE"
            ip r | tee -a "$LOG_FILE"
            ;;
        "Interface")
            log_info "Exibindo dados da interface $INTERFACE"
            ethtool "$INTERFACE" | tee -a "$LOG_FILE"
            ip -s link show "$INTERFACE" | tee -a "$LOG_FILE"
            ;;
        "DNS")
            log_info "Executando testes de DNS"
            cat /etc/resolv.conf | tee -a "$LOG_FILE"
            dig google.com +short | tee -a "$LOG_FILE"
            host google.com | tee -a "$LOG_FILE"
            ;;
        "Ping")
            log_info "Executando testes de Ping e MTU"
            ping -c 4 8.8.8.8 | tee -a "$LOG_FILE"
            ping -c 4 google.com | tee -a "$LOG_FILE"
            ping -M do -s 1472 -c 2 8.8.8.8 | tee -a "$LOG_FILE"
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
