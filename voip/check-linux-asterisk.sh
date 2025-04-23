#!/bin/bash

#---> Limpa a tela:
clear

#---> Mostra o pai da criança:
echo -e "\e[1;32m╔════════════════════════════════════════════╗\e[0m"
echo -e "\e[1;32m║       TOOLBOX - By Murilo Prestes          ║\e[0m"
echo -e "\e[1;32m║     GitHub: https://github.com/n0nsi       ║\e[0m"
echo -e "\e[1;32m╚════════════════════════════════════════════╝\e[0m"

#---> Listar informações do sistema:
echo -e "\e[1;32m\n ======== [ INFORMAÇÕES DO SISTEMA ] ========\e[0m"
echo -e "\n>> Hostname e SO:"
hostnamectl | grep -E "Static hostname|Operating System|Kernel|Architecture"

#---> Listar informações de data e uptime da máquina
echo -e "\n>> Data e Uptime:"
echo -n "Data: "; date
echo -n "Uptime: "; uptime -p

#---> Listar informações de CPU
echo -e "\n>> CPU:"
lscpu | grep -E "ID de fornecedor|Nome do modelo"

#---> Listar informações de RAM
echo -e "\n>> Memória (RAM):"
free -h

#---> Listar partições:
echo -e "\n>> Disco (Partições):"
df -h --output=source,size,used,avail,target -x tmpfs -x devtmpfs | grep -vE "^Filesystem|tmpfs|udev"

#---> Listar informações totalizadas:
echo -e "\n>> Espaço total em disco:"
df -BM --total -x tmpfs -x devtmpfs | awk '/total/ { 
  printf "Total: %.2f GB\n", $2/1024
  printf "Usado: %.2f GB\n", $3/1024
  printf "Disponível: %.2f GB\n", $4/1024 
}'

#---> Listar interfaces e seus endereços de rede:
echo -e "\n\e[1;32m\n======== [ REDE ] ========\e[0m"
ip -br a | awk '{
    print "Interface: " $1
    print "IPv4:       " $3
    print "IPv6:    " $4
    print ""
}'

#---> Listar as rotas de rede:
echo -e "\n>> Rotas:"
ip route | awk '{ print "Destino: "$1" | Via: "$3" | Interface: "$5 }' 2>/dev/null

#---> Listar zonas de DNS configuradas:
echo -e "\n>> DNS configurado:"
grep "nameserver" /etc/resolv.conf | awk '
BEGIN {
    label[1] = "Primário"
    label[2] = "Secundário"
    label[3] = "Terciário"
    label[4] = "Quaternário"
    label[5] = "Quinto"
    label[6] = "Sexto"
}
{
    i++
    printf "%-10s: %s\n", label[i] ? label[i] : "DNS " i, $2
}'

echo -e "\n\e[1;32m\n======== [ SETUP DE REDE NO ASTERISK ] ========\e[0m"
#---> Listar IP externo configurado no Asterisk:
echo -e "\n>> IP externo configurado no Asterisk:"
grep -h '^[[:space:]]*externip[[:space:]]*=' /etc/asterisk/*.conf

#---> Listar IP's locais configurados no Asterisk:
echo -e "\n>> Localnets configurados no Asterisk:"
grep -h '^[[:space:]]*localnet[[:space:]]*=' /etc/asterisk/*.conf

#---> Listar IP externo no qual a máquina está saindo para a internet:
echo -e "\n>> IP externo atual (saída para internet):"
wget -q -O - ipinfo.io/ip 

#---> Encerrando o script
echo -e "\n\n\e[1;32m\n========[ FIM DO RELATÓRIO ] ========\e[0m"
