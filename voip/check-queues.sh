#!/bin/bash
#---> Mostra o pai da criança:
echo -e "\e[1;32m╔════════════════════════════════════════════╗\e[0m"
echo -e "\e[1;32m║       TOOLBOX - By Murilo Prestes          ║\e[0m"
echo -e "\e[1;32m║     GitHub: https://github.com/n0nsi       ║\e[0m"
echo -e "\e[1;32m╚════════════════════════════════════════════╝\e[0m"

# Executar o comando Asterisk e salvar a saída em uma variável
output=$(asterisk -rx 'queue show')

# Extrair os números das filas
queue_numbers=$(echo "$output" | grep -oP '\d+(?= has)')

# Prompt para o usuário escolher uma fila ou todas
echo "Deseja consultar uma fila específica ou todas as filas?"
echo "1. Fila específica"
echo "2. Todas as filas"
read -p "Escolha uma opção (1/2): " option

# Função para extrair e imprimir os membros de uma fila
function extract_and_print_members() {
    local qn=$1
    local strategy=$2
    local members=$(echo "$output" | awk -v qn="$qn" -F'\n' -v RS='' '$0 ~ qn {print}' | grep -oP 'Local/\K[^@]+')

    echo "N° da Fila: $qn"
    echo "Estratégia de Ring: $strategy"
    echo "Membros:"
    for member in $members; do
        echo "$member"
    done
    echo "-----------------------------"
}

# Verificar a escolha do usuário
if [ "$option" == "1" ]; then
    read -p "Digite o número da fila que deseja consultar: " queue_number
    strategy=$(echo "$output" | grep -oP "$queue_number.*in '\K[^']+")
    extract_and_print_members "$queue_number" "$strategy"
elif [ "$option" == "2" ]; then
    # Consultar todas as filas
    for queue_number in $queue_numbers; do
        strategy=$(echo "$output" | grep -oP "$queue_number.*in '\K[^']+")
        extract_and_print_members "$queue_number" "$strategy"
    done
else
    echo "Opção inválida."
fi
