#!/bin/bash

#---> Mostra o pai da criança:
echo -e "\e[1;32m╔════════════════════════════════════════════╗\e[0m"
echo -e "\e[1;32m║       TOOLBOX - By Murilo Prestes          ║\e[0m"
echo -e "\e[1;32m║     GitHub: https://github.com/n0nsi       ║\e[0m"
echo -e "\e[1;32m╚════════════════════════════════════════════╝\e[0m"

# Executa o comando 'database show' no Asterisk e filtra as linhas com 'user_agent'
output=$(asterisk -rx 'database show' | grep "user_agent")

# Inicializa uma variável para contar a quantidade de ramais
num_ramais=0

# Use um delimitador personalizado para dividir a linha em campos
IFS="@"
# Loop através das linhas de saída
while IFS= read -r line; do
    # Incrementa o contador de ramais
    ((num_ramais++))

    # Extrai as informações necessárias
    via_addr=$(echo "$line" | grep -oP '(?<=via_addr":").*?(?=",")')
    endpoint=$(echo "$line" | grep -oP '(?<=endpoint":").*?(?=",")')
    user_agent=$(echo "$line" | grep -oP '(?<=user_agent":").*?(?=")')

    # Imprime o cabeçalho do ramal
    #echo "-----------$num_ramais-----------"

    # Imprime as informações formatadas
    echo "Ramal: $endpoint"
    echo "IP de Registro: $via_addr"
    echo "Dispositivo de Registro: $user_agent"
    echo "--------------------------------------------------------------"
done <<< "$output"

# Imprime a quantidade total de ramais
echo "Total de Ramais: $num_ramais"