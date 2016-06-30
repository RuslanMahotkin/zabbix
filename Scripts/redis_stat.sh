#!/bin/bash
# Отправка статистики сервера Redis на сервер Zabbix

# Получение строки статистики. Параметры redis-cli:
#  -s сокет	полное имя файла сокета;
#  info all	команда получения всей информации и статистики	
RespStr=$(/usr/bin/redis-cli -s /полное/имя/файла/сокета info all 2>/dev/null)
# Статистика недоступна - возврат статуса сервиса - 'не работает'
[ $? != 0 ] && echo 0 && exit 1

# В командной строке нет параметров - отправка данных
if [ -z $1 ]; then
 # Фильтрация, форматирование и отправка данных статистики серверу Zabbix
 (cat <<EOF
$RespStr
EOF
 ) | awk -F: '$1~/^(uptime_in_seconds|(blocked|connected)_clients|used_memory(_rss|_peak)?|total_(connections_received|commands_processed)|instantaneous_ops_per_sec|total_net_(input|output)_bytes|rejected_connections|(expired|evicted)_keys|keyspace_(hits|misses))$/ {
  print "- redis." $1, int($2)
 }
 $1~/^cmdstat_(get|setex|exists|command)$/ {
  split($2, C, ",|=")
  print "- redis." $1, int(C[2])
 }
 $1~/^db[0-9]+$/ {
  split($2, C, ",|=")
  for(i=1; i < 6; i+=2) print "- redis." C[i] "[" $1 "]", int(C[i+1])
 }' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
 # Возврат статуса сервиса - 'работает'
 echo 1
 exit 0

# Обнаружение БД
elif [ "$1" = 'db' ]; then
 # Формирование списка БД в формате JSON
 (cat <<EOF
$RespStr
EOF
 ) | awk -F: '$1~/^db[0-9]+$/ {
  OutStr=OutStr es "{\"{#DBNAME}\":\"" $1 "\"}"
  es=","
 }
 END { print "{\"data\":[" OutStr "]}" }'
fi
