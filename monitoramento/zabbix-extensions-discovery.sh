#!/bin/bash

# Gera descoberta de ramais SIP em JSON para Zabbix

JSON_DATA=$(asterisk -rx "sip show peers" | awk '
BEGIN {
  print "{\n  \"data\":["
  first = 1
}
$0 ~ /^[0-9]+/ {
  ext=$1
  ip="null"
  device="null"
  for (i=1; i<=NF; i++) {
    if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) ip=$i
    if ($i == "OK" || $i == "UNKNOWN") device=$(i-1)
  }

  if (!first) print ","
  first = 0

  print "    { \"{#EXTEN}\":\"" ext "\", \"{#IP}\":\"" ip "\", \"{#DEVICE}\":\"" device "\" }"
}
END {
  print "  ]\n}"
}')
echo "$JSON_DATA"
