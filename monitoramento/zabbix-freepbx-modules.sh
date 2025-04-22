#!/bin/bash

# Váriaveis para o Log
LOG="/var/log/check-modules-freepbx.log"
DATA_HORA=$(date '+%Y-%m-%d %H:%M:%S')

# Cria o log se não existir
[ ! -f "$LOG" ] && touch "$LOG" && chmod 644 "$LOG"

# Pega do FreePBX a lista de módulos, nome e status
modulos=$(fwconsole ma list | tail -n +3 | awk -F'|' '{gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $4); print $2, $4}')

todos_ok=true

# Verifica se algum módulo está desabilitado
while IFS= read -r linha; do
  nome=$(echo "$linha" | awk '{print $1}' | xargs)
  status=$(echo "$linha" | awk '{print $2}' | xargs)

  if echo "$status" | grep -iq "Desabilitado"; then
    todos_ok=false
    echo "$DATA_HORA [PROBLEM] Módulo com problema detectado: $nome, $status" >> "$LOG"
  fi
done <<< "$modulos"

# Se todos os módulos estiverem habilitados
if $todos_ok; then
  echo "OK"
else
  echo "PROBLEM"
fi
