#!/bin/bash

#---> Mostra o pai da criança na tela:
echo -e "\e[1;32m╔════════════════════════════════════════════╗\e[0m"
echo -e "\e[1;32m║       TOOLBOX - By Murilo Prestes          ║\e[0m"
echo -e "\e[1;32m║     GitHub: https://github.com/n0nsi       ║\e[0m"
echo -e "\e[1;32m╚════════════════════════════════════════════╝\e[0m"

# Váriaveis para o Log
LOG="/var/log/check-modules-freepbx.log"
DATA_HORA=$(date '+%Y-%m-%d %H:%M:%S')

# Cria o log se não existir
[ ! -f "$LOG" ] && touch "$LOG" && chmod 644 "$LOG"

echo "Checando todos os módulos do FreePBX..."

# Pega do FreePBX a lista de módulos, nome e status (depois do primeiro e terceiro pipe)
modulos=$(fwconsole ma list | tail -n +3 | awk -F'|' '{gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $4); print $2, $4}')

todos_ok=true

# Verifica se algum módulo está desabilitado
# O loop lê cada linha da variável 'modulos' e verifica o status
# Se o status contiver "Desabilitado", imprime o nome e o status do módulo e registra no log
# Se todos os módulos estiverem habilitados, imprime uma mensagem de sucesso e registra no log
while IFS= read -r linha; do
  nome=$(echo "$linha" | awk '{print $1}' | xargs)
  status=$(echo "$linha" | awk '{print $2}' | xargs)

  if echo "$status" | grep -iq "Desabilitado"; then
    todos_ok=false
    echo
    echo "Módulo com problema detectado:"
    echo "Módulo: $nome"
    echo "Status: $status"
    echo "$DATA_HORA [PROBLEM] Módulo com problema detectado: $nome, $status" >> "$LOG"
  fi
done <<< "$modulos"

# Se todos os módulos estiverem habilitados, imprime uma mensagem de sucesso
# e registra no log
if $todos_ok; then
  echo "Check OK, todos os módulos estão habilitados e nenhuma ação é necessária."
  echo "$DATA_HORA [SUCESS] Check OK, todos os módulos habilitados" >> "$LOG"
fi
